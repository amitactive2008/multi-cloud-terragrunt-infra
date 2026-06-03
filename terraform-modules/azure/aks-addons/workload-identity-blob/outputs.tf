output "managed_identity_client_id" {
  description = "Client ID of the User-Assigned Managed Identity. Set as annotation 'azure.workload.identity/client-id' on the Kubernetes service account."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "managed_identity_object_id" {
  description = "Object ID of the User-Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "federated_credential_id" {
  description = "ID of the federated identity credential."
  value       = azurerm_federated_identity_credential.this.id
}
