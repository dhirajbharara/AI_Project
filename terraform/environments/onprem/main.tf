# On-Premises GPU Cluster — Primary inference workload

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

module "onprem_cluster" {
  source = "../../modules/onprem-vm"

  name_prefix    = "llm-onprem"
  environment    = "production"
  gpu_node_count = 2
  cpu_node_count = 1

  gpu_hostnames    = ["gpu-node-01.datacenter.local", "gpu-node-02.datacenter.local"]
  gpu_ip_addresses = ["192.168.10.11", "192.168.10.12"]
  cpu_hostnames    = ["cpu-node-01.datacenter.local"]
  cpu_ip_addresses = ["192.168.10.21"]

  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
}

variable "ssh_user" {
  type    = string
  default = "admin"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

output "gpu_endpoints" {
  value = module.onprem_cluster.api_endpoints
}
