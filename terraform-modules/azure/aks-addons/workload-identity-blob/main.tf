terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# User-Assigned Managed Identity for the workload
resource "azurerm_user_assigned_identity" "this" {
  name                = var.managed_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Federated identity credential: links Kubernetes service account → managed identity
# This is Azure's equivalent of EKS Pod Identity
resource "azurerm_federated_identity_credential" "this" {
  name                = "${var.service_account_namespace}-${var.service_account_name}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"
}

# Grant "Storage Blob Data Contributor" on the target storage container
data "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  resource_group_name = var.storage_resource_group
}

resource "azurerm_role_assignment" "blob_contributor" {
  scope                = "${data.azurerm_storage_account.this.id}/blobServices/default/containers/${var.blob_container_name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}
