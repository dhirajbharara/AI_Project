# Azure VM deployment — Managed cloud alternative

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "llm_vm" {
  source = "../../modules/azure-vm"

  name_prefix    = "llm-azure"
  location       = "eastus"
  environment    = "production"
  enable_gpu     = false
  enable_lb      = true
  ssh_public_key = var.ssh_public_key

  tags = {
    Project   = "multi-arch-llm-pipeline"
    ManagedBy = "terraform"
  }
}

variable "ssh_public_key" {
  type = string
}

output "api_endpoint" {
  value = module.llm_vm.api_endpoint
}
