# =============================================================================
# AWS EC2 Module — Cloud VM deployment target
#
# Why Terraform for infrastructure?
# - Infrastructure as Code (IaC): version-controlled, repeatable, auditable
# - Declarative: describe desired state, Terraform reconciles differences
# - Multi-cloud: same patterns extend to Azure and on-prem with different providers
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- Networking ---

resource "aws_vpc" "llm" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "llm" {
  vpc_id = aws_vpc.llm.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.llm.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-${count.index + 1}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.llm.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.llm.id
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Security Groups (Firewall Rules) ---

resource "aws_security_group" "llm_api" {
  name        = "${var.name_prefix}-llm-api-sg"
  description = "Security group for LLM inference API"
  vpc_id      = aws_vpc.llm.id

  # HTTP API access
  ingress {
    description = "FastAPI inference API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Health check / load balancer
  ingress {
    description = "Health checks from ALB"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH for Ansible provisioning (restrict in production)
  ingress {
    description = "SSH for Ansible"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # Prometheus scraping
  ingress {
    description = "Prometheus metrics"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.monitoring_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-llm-api-sg" })
}

# --- Storage ---

resource "aws_ebs_volume" "model_cache" {
  count             = var.enable_gpu ? 0 : var.instance_count
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  size              = var.model_cache_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-model-cache-${count.index + 1}" })
}

resource "aws_volume_attachment" "model_cache" {
  count       = var.enable_gpu ? 0 : var.instance_count
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.model_cache[count.index].id
  instance_id = aws_instance.llm[count.index].id
}

# --- Compute ---

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "llm" {
  count                       = var.instance_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.enable_gpu ? var.gpu_instance_type : var.cpu_instance_type
  subnet_id                   = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids      = [aws_security_group.llm_api.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true
  iam_instance_profile        = var.iam_instance_profile

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    region            = var.aws_region
    hardware_type     = var.enable_gpu ? "gpu" : "cpu"
    deployment_target = "aws-ec2"
    environment       = var.environment
  }))

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-llm-${count.index + 1}"
    HardwareType  = var.enable_gpu ? "gpu" : "cpu"
    ModelVersion  = var.model_version
    Environment   = var.environment
  })
}

# --- Load Balancer (active-active / failover) ---

resource "aws_lb" "llm" {
  count              = var.enable_alb ? 1 : 0
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.llm_api.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })
}

resource "aws_lb_target_group" "llm" {
  count    = var.enable_alb ? 1 : 0
  name     = "${var.name_prefix}-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.llm.id

  health_check {
    enabled             = true
    path                = "/ready"
    port                = "8000"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-tg" })
}

resource "aws_lb_target_group_attachment" "llm" {
  count            = var.enable_alb ? var.instance_count : 0
  target_group_arn = aws_lb_target_group.llm[0].arn
  target_id        = aws_instance.llm[count.index].id
  port             = 8000
}

resource "aws_lb_listener" "http" {
  count             = var.enable_alb ? 1 : 0
  load_balancer_arn = aws_lb.llm[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.llm[0].arn
  }
}
