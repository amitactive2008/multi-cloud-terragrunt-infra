# terraform-modules/azure/aks-addons/workload-identity-blob

Creates a **User-Assigned Managed Identity** with a **federated credential** that allows a Kubernetes service account to authenticate as the identity via OIDC. The identity is granted `Storage Blob Data Contributor` on a specific Blob Storage container.

This is the Azure equivalent of `eks-addons/pod-identity-s3` (AWS EKS Pod Identity + S3 access).

## How Workload Identity Works

```
Pod (annotated SA)  →  OIDC token  →  Azure AD federation
                                             ↓
                               User-Assigned Managed Identity
                                             ↓
                               Storage Blob Data Contributor
                                             ↓
                                  Blob container access
```

1. AKS OIDC issuer issues a token for the Kubernetes service account
2. Azure AD validates the token against the federated credential
3. Pod gets an Azure AD access token scoped to the managed identity
4. Managed identity has RBAC role on the Blob container

## Resources Created

| Resource | Description |
|----------|-------------|
| `azurerm_user_assigned_identity` | Managed identity for the workload |
| `azurerm_federated_identity_credential` | Links K8s SA to managed identity |
| `azurerm_role_assignment` | `Storage Blob Data Contributor` on Blob container |

## Usage

```hcl
module "workload_identity_blob" {
  source              = "../../terraform-modules/azure/aks-addons/workload-identity-blob"
  cluster_name        = "dev-aks"
  resource_group_name = "dev-aks-rg"
  location            = "eastus"
  subscription_id     = "00000000-…"
  tenant_id           = "00000000-…"
  environment         = "dev"
  oidc_issuer_url     = "https://…"

  storage_account_name      = "devappblobstorage"
  storage_resource_group    = "dev-data-rg"
  blob_container_name       = "app-data"

  service_account_name      = "blob-access-sa"
  service_account_namespace = "default"
  managed_identity_name     = "dev-blob-access-identity"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | `string` | — | AKS cluster name |
| `resource_group_name` | `string` | — | Cluster resource group |
| `location` | `string` | — | Azure region |
| `subscription_id` | `string` | — | Azure subscription ID |
| `tenant_id` | `string` | — | Azure tenant ID |
| `environment` | `string` | — | Environment name |
| `oidc_issuer_url` | `string` | — | OIDC issuer URL from AKS |
| `storage_account_name` | `string` | — | Existing storage account name |
| `storage_resource_group` | `string` | — | Resource group of the storage account |
| `blob_container_name` | `string` | — | Container to grant access to |
| `service_account_name` | `string` | — | Kubernetes service account name |
| `service_account_namespace` | `string` | `default` | Kubernetes namespace |
| `managed_identity_name` | `string` | — | Name of the managed identity to create |
| `tags` | `map(string)` | `{}` | Tags |

## Outputs

| Name | Description |
|------|-------------|
| `managed_identity_client_id` | Client ID — annotate the K8s service account with this |
| `managed_identity_object_id` | Object ID of the managed identity |
| `federated_credential_id` | Federated credential resource ID |

## Kubernetes Service Account

After applying, annotate the Kubernetes service account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: blob-access-sa
  namespace: default
  annotations:
    azure.workload.identity/client-id: "<managed_identity_client_id output>"
  labels:
    azure.workload.identity/use: "true"
```

Pods using this SA must also have the label:
```yaml
labels:
  azure.workload.identity/use: "true"
```
