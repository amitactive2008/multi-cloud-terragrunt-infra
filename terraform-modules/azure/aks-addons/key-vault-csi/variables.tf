variable "cluster_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
variable "environment" { type = string }
variable "oidc_issuer_url" { type = string }
variable "key_vault_name" { type = string }
variable "key_vault_resource_group" { type = string }
variable "key_vault_sku" { type = string; default = "standard" }
variable "soft_delete_retention_days" { type = number; default = 7 }
variable "purge_protection_enabled" { type = bool; default = false }
variable "kubelet_identity_object_id" { type = string }
variable "tags" { type = map(string); default = {} }
