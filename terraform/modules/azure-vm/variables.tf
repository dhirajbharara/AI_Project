variable "name_prefix" {
  type = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "vnet_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.1.1.0/24"
}

variable "admin_cidr" {
  type    = string
  default = "10.0.0.0/8"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  type = string
}

variable "cpu_vm_size" {
  description = "Azure VM size for CPU (Standard_D4s_v3 = 4 vCPU, 16GB RAM)"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "gpu_vm_size" {
  description = "Azure VM size for GPU (NC4as_T4_v3 = NVIDIA T4)"
  type        = string
  default     = "Standard_NC4as_T4_v3"
}

variable "enable_gpu" {
  type    = bool
  default = false
}

variable "enable_lb" {
  type    = bool
  default = true
}

variable "os_disk_size_gb" {
  type    = number
  default = 128
}

variable "model_cache_size_gb" {
  type    = number
  default = 50
}

variable "tags" {
  type    = map(string)
  default = {}
}
