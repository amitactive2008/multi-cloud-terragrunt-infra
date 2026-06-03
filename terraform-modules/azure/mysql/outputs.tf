output "server_name" {
  description = "Name of the MySQL Flexible Server."
  value       = azurerm_mysql_flexible_server.this.name
}

output "server_fqdn" {
  description = "Fully qualified domain name of the MySQL server."
  value       = azurerm_mysql_flexible_server.this.fqdn
}

output "resource_group_name" {
  description = "Resource group of the MySQL server."
  value       = azurerm_resource_group.this.name
}

output "administrator_login" {
  description = "Administrator username."
  value       = azurerm_mysql_flexible_server.this.administrator_login
}

output "administrator_password" {
  description = "Administrator password (sensitive)."
  value       = random_password.mysql.result
  sensitive   = true
}

output "database_names" {
  description = "List of created database names."
  value       = [for db in azurerm_mysql_flexible_database.this : db.name]
}
