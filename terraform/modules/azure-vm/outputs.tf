output "vm_public_ip" {
  value = azurerm_public_ip.llm.ip_address
}

output "api_endpoint" {
  value = "http://${azurerm_public_ip.llm.ip_address}:8000"
}

output "resource_group_name" {
  value = azurerm_resource_group.llm.name
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.llm.id
}
