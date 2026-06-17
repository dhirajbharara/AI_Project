# AWS Region A (us-east-1) — Active-Active deployment
# Part of multi-region hybrid architecture

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "llm-pipeline-tfstate"
    key            = "aws-region-a/terraform.tfstate"
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
  region = "us-east-1"
}

module "llm_cluster" {
  source = "../../modules/aws-ec2"

  name_prefix        = "llm-region-a"
  aws_region         = "us-east-1"
  environment        = "production"
  availability_zones = ["us-east-1a", "us-east-1b"]
  instance_count     = 2
  enable_gpu         = false
  enable_alb         = true
  key_pair_name      = var.key_pair_name

  tags = {
    Project    = "multi-arch-llm-pipeline"
    Region     = "us-east-1"
    Role       = "active"
    ManagedBy  = "terraform"
  }
}

variable "key_pair_name" {
  type = string
}

output "api_endpoint" {
  value = module.llm_cluster.api_endpoint
}
