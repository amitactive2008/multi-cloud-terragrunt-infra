variable "cluster_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
variable "environment" { type = string }
variable "oidc_issuer_url" { type = string }
variable "storage_account_name" { type = string }
variable "storage_resource_group" { type = string }
variable "blob_container_name" { type = string }
variable "service_account_name" { type = string }
variable "service_account_namespace" { type = string; default = "default" }
variable "managed_identity_name" { type = string }
variable "tags" { type = map(string); default = {} }
