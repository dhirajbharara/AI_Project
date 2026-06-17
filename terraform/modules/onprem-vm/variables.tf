variable "name_prefix" {
  type = string
}

variable "environment" {
  type    = string
  default = "production"
}

variable "gpu_node_count" {
  description = "Number of on-prem GPU servers"
  type        = number
  default     = 2
}

variable "cpu_node_count" {
  description = "Number of on-prem CPU servers (failover/overflow)"
  type        = number
  default     = 1
}

variable "gpu_hostnames" {
  type    = list(string)
  default = ["gpu-node-01", "gpu-node-02"]
}

variable "gpu_ip_addresses" {
  type    = list(string)
  default = ["192.168.10.11", "192.168.10.12"]
}

variable "cpu_hostnames" {
  type    = list(string)
  default = ["cpu-node-01"]
}

variable "cpu_ip_addresses" {
  type    = list(string)
  default = ["192.168.10.21"]
}

variable "ssh_user" {
  type    = string
  default = "admin"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "ssh_port" {
  type    = number
  default = 22
}

variable "internal_network_cidr" {
  type    = string
  default = "192.168.10.0/24"
}

variable "admin_network_cidr" {
  type    = string
  default = "192.168.1.0/24"
}

variable "monitoring_network_cidr" {
  type    = string
  default = "192.168.20.0/24"
}

variable "model_version" {
  type    = string
  default = "1.0.0"
}
