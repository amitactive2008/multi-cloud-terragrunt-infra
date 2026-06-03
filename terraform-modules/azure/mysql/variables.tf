variable "name" {
  description = "Name of the MySQL Flexible Server."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "mysql_version" {
  description = "MySQL version (e.g. 8.0.21)."
  type        = string
  default     = "8.0.21"
}

variable "sku_name" {
  description = "SKU name for the MySQL server."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_size_gb" {
  description = "Storage size in GB."
  type        = number
  default     = 20
}

variable "iops" {
  description = "Storage IOPS."
  type        = number
  default     = 396
}

variable "administrator_login" {
  description = "Administrator username."
  type        = string
}

variable "database_subnet_id" {
  description = "ID of the delegated subnet for MySQL Flexible Server."
  type        = string
}

variable "private_dns_zone_vnet_id" {
  description = "ID of the VNet to link to the private DNS zone."
  type        = string
}

variable "databases" {
  description = "List of database names to create."
  type        = list(string)
  default     = []
}

variable "backup_retention_days" {
  description = "Backup retention days."
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups."
  type        = bool
  default     = false
}

variable "key_vault_id" {
  description = "Key Vault ID to store the generated password as a secret."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
