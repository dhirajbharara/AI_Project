output "gpu_node_ips" {
  value = var.gpu_ip_addresses
}

output "cpu_node_ips" {
  value = var.cpu_ip_addresses
}

output "api_endpoints" {
  value = [for ip in var.gpu_ip_addresses : "http://${ip}:8000"]
}

output "firewall_rules_file" {
  value = local_file.firewall_rules.filename
}
