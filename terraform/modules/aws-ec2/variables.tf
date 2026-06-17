variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed SSH access"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "monitoring_cidr_blocks" {
  description = "CIDR blocks for Prometheus scraping"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
  default     = 2
}

variable "cpu_instance_type" {
  description = "EC2 instance type for CPU deployments"
  type        = string
  default     = "t3.xlarge"
}

variable "gpu_instance_type" {
  description = "EC2 instance type for GPU deployments (g4dn.xlarge has NVIDIA T4)"
  type        = string
  default     = "g4dn.xlarge"
}

variable "enable_gpu" {
  description = "Deploy GPU instances instead of CPU"
  type        = bool
  default     = false
}

variable "key_pair_name" {
  description = "AWS key pair name for SSH access"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile for EC2"
  type        = string
  default     = ""
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 100
}

variable "model_cache_size_gb" {
  description = "Additional EBS volume for model cache"
  type        = number
  default     = 50
}

variable "enable_alb" {
  description = "Enable Application Load Balancer for active-active traffic"
  type        = bool
  default     = true
}

variable "model_version" {
  description = "LLM model version being deployed"
  type        = string
  default     = "1.0.0"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
