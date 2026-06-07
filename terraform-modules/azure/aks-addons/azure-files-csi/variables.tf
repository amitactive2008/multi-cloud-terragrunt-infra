variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group of the AKS cluster."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from AKS (used for Workload Identity)."
  type        = string
}

variable "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity, used for role assignments."
  type        = string
}

variable "storage_account_name" {
  description = "Name of the Azure Storage Account for Azure Files. Must be globally unique, 3-24 lowercase alphanumeric characters."
  type        = string
}

variable "storage_account_tier" {
  description = "Storage account tier: Standard or Premium."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "storage_account_tier must be 'Standard' or 'Premium'."
  }
}

variable "storage_account_replication_type" {
  description = "Storage account replication type: LRS, ZRS, GRS, RAGRS."
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS"], var.storage_account_replication_type)
    error_message = "storage_account_replication_type must be one of: LRS, ZRS, GRS, RAGRS."
  }
}

variable "enable_nfs_storage_class" {
  description = "Whether to create an NFS StorageClass (requires Premium storage account tier)."
  type        = bool
  default     = false
}

variable "smb_storage_class_name" {
  description = "Name of the SMB (CIFS) Azure Files StorageClass."
  type        = string
  default     = "azurefile-smb"
}

variable "nfs_storage_class_name" {
  description = "Name of the NFS Azure Files StorageClass (only created when enable_nfs_storage_class = true)."
  type        = string
  default     = "azurefile-nfs"
}

variable "tags" {
  description = "Tags to apply to Azure resources."
  type        = map(string)
  default     = {}
}
