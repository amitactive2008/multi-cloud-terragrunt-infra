terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "random_password" "mysql" {
  length           = 20
  special          = true
  override_special = "!#$%"
}

resource "azurerm_private_dns_zone" "mysql" {
  name                = "${var.name}.private.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${var.name}-vnet-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = var.private_dns_zone_vnet_id
  tags                  = var.tags
}

resource "azurerm_mysql_flexible_server" "this" {
  name                   = var.name
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  administrator_login    = var.administrator_login
  administrator_password = random_password.mysql.result
  sku_name               = var.sku_name
  version                = var.mysql_version
  delegated_subnet_id    = var.database_subnet_id
  private_dns_zone_id    = azurerm_private_dns_zone.mysql.id
  backup_retention_days  = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  storage {
    size_gb = var.storage_size_gb
    iops    = var.iops
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]

  tags = var.tags
}

resource "azurerm_mysql_flexible_database" "this" {
  for_each            = toset(var.databases)
  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
  server_name         = azurerm_mysql_flexible_server.this.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}
