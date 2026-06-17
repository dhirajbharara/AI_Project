# AWS Region B (eu-west-1) — Active-Passive / Failover region

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "llm-pipeline-tfstate"
    key            = "aws-region-b/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "llm-pipeline-tflock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "llm_cluster" {
  source = "../../modules/aws-ec2"

  name_prefix        = "llm-region-b"
  aws_region         = "eu-west-1"
  environment        = "production"
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  instance_count     = 1
  enable_gpu         = false
  enable_alb         = true
  key_pair_name      = var.key_pair_name

  tags = {
    Project    = "multi-arch-llm-pipeline"
    Region     = "eu-west-1"
    Role       = "passive-failover"
    ManagedBy  = "terraform"
  }
}

variable "key_pair_name" {
  type = string
}

output "api_endpoint" {
  value = module.llm_cluster.api_endpoint
}
