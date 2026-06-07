output "storage_account_id" {
  description = "ID of the Azure Storage Account used for Azure Files"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the Azure Storage Account"
  value       = azurerm_storage_account.this.name
}

output "storage_account_primary_endpoint" {
  description = "Primary file service endpoint of the storage account"
  value       = azurerm_storage_account.this.primary_file_endpoint
}

output "smb_storage_class" {
  description = "Name of the SMB Azure Files StorageClass"
  value       = kubernetes_storage_class.azurefile_smb.metadata[0].name
}

output "nfs_storage_class" {
  description = "Name of the NFS Azure Files StorageClass (empty string when enable_nfs_storage_class = false)"
  value       = var.enable_nfs_storage_class ? kubernetes_storage_class.azurefile_nfs[0].metadata[0].name : ""
}

output "smb_secret_name" {
  description = "Name of the Kubernetes secret holding SMB credentials"
  value       = kubernetes_secret.azurefile_smb.metadata[0].name
}
