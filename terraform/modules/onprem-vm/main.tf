# =============================================================================
# On-Premises VM Module — GPU server deployment target
#
# Why a separate on-prem module?
# - On-prem uses null_resource + SSH provisioning instead of cloud APIs
# - GPU servers typically live in a private datacenter network
# - Terraform manages the desired state; Ansible configures the actual host
# =============================================================================

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# On-prem inventory is managed via static configuration
# In production, integrate with VMware vSphere, Proxmox, or bare-metal BMC APIs

resource "null_resource" "onprem_gpu_cluster" {
  count = var.gpu_node_count

  triggers = {
    hostname     = var.gpu_hostnames[count.index]
    ip_address   = var.gpu_ip_addresses[count.index]
    model_version = var.model_version
  }

  connection {
    type        = "ssh"
    host        = var.gpu_ip_addresses[count.index]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    port        = var.ssh_port
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'On-prem GPU node ${count.index + 1} registered'",
      "mkdir -p /etc/llm-pipeline",
      "echo 'HARDWARE_TYPE=gpu' > /etc/llm-pipeline/config.env",
      "echo 'DEPLOYMENT_TARGET=onprem-gpu' >> /etc/llm-pipeline/config.env",
      "echo 'ENVIRONMENT=${var.environment}' >> /etc/llm-pipeline/config.env",
      "echo 'NODE_INDEX=${count.index}' >> /etc/llm-pipeline/config.env",
    ]
  }
}

resource "null_resource" "onprem_cpu_nodes" {
  count = var.cpu_node_count

  triggers = {
    hostname   = var.cpu_hostnames[count.index]
    ip_address = var.cpu_ip_addresses[count.index]
  }

  connection {
    type        = "ssh"
    host        = var.cpu_ip_addresses[count.index]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    port        = var.ssh_port
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/llm-pipeline",
      "echo 'HARDWARE_TYPE=cpu' > /etc/llm-pipeline/config.env",
      "echo 'DEPLOYMENT_TARGET=onprem-cpu' >> /etc/llm-pipeline/config.env",
      "echo 'ENVIRONMENT=${var.environment}' >> /etc/llm-pipeline/config.env",
    ]
  }
}

# Firewall rules documentation (applied via Ansible iptables role)
resource "local_file" "firewall_rules" {
  filename = "${path.module}/generated/firewall-rules-${var.name_prefix}.json"
  content = jsonencode({
    description = "On-prem firewall rules for LLM GPU cluster"
    rules = [
      {
        name        = "allow-api-internal"
        direction   = "inbound"
        protocol    = "tcp"
        port        = 8000
        source      = var.internal_network_cidr
        description = "LLM inference API from internal network"
      },
      {
        name        = "allow-ssh-admin"
        direction   = "inbound"
        protocol    = "tcp"
        port        = 22
        source      = var.admin_network_cidr
        description = "SSH for Ansible provisioning"
      },
      {
        name        = "allow-prometheus"
        direction   = "inbound"
        protocol    = "tcp"
        port        = 8000
        source      = var.monitoring_network_cidr
        description = "Prometheus metrics scraping"
      },
      {
        name        = "allow-gpu-cluster"
        direction   = "inbound"
        protocol    = "tcp"
        port        = 11434
        source      = var.internal_network_cidr
        description = "Ollama inter-node communication"
      }
    ]
  })
}
