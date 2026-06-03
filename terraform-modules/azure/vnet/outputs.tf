output "vnet_id" {
  description = "ID of the Virtual Network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the Virtual Network."
  value       = azurerm_virtual_network.this.name
}

output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.this.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet."
  value       = azurerm_subnet.this["aks"].id
}

output "database_subnet_id" {
  description = "ID of the database subnet."
  value       = azurerm_subnet.this["database"].id
}

output "privatelink_subnet_id" {
  description = "ID of the private link subnet."
  value       = azurerm_subnet.this["privatelink"].id
}

output "subnet_ids" {
  description = "Map of all subnet IDs keyed by subnet name."
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}
