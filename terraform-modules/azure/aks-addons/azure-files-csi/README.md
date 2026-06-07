# aks-addons/azure-files-csi

Configures [Azure Files CSI Driver](https://github.com/kubernetes-sigs/azurefile-csi-driver) support for AKS by provisioning a dedicated Azure Storage Account, granting the kubelet managed identity the required RBAC role, creating a Kubernetes secret for static provisioning, and deploying dynamic StorageClasses for both SMB and NFS protocols.

> **Note:** The Azure Files CSI driver is built into AKS — no additional installation is required. This module only configures the storage infrastructure and Kubernetes resources needed to use it.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `azurerm_storage_account` | `this` | Dedicated storage account for Azure Files shares |
| `azurerm_role_assignment` | `smb_share_contributor` | Grants kubelet identity `Storage File Data SMB Share Contributor` |
| `kubernetes_secret` | `azure-files-smb-secret` | SMB credentials secret in `kube-system` for static PV use |
| `kubernetes_storage_class` | `azurefile-smb` | Dynamic SMB StorageClass (ReadWriteMany / ReadWriteOnce) |
| `kubernetes_storage_class` | `azurefile-nfs` | Dynamic NFS StorageClass (only when `enable_nfs_storage_class = true`) |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | AKS cluster name |
| `resource_group_name` | string | — | Resource group of the AKS cluster |
| `location` | string | — | Azure region |
| `subscription_id` | string | — | Azure subscription ID |
| `environment` | string | — | Environment name |
| `oidc_issuer_url` | string | — | OIDC issuer URL from AKS |
| `kubelet_identity_object_id` | string | — | Object ID of the AKS kubelet managed identity |
| `storage_account_name` | string | — | Globally unique storage account name (3-24 lowercase alphanumeric) |
| `storage_account_tier` | string | `"Standard"` | `Standard` or `Premium` |
| `storage_account_replication_type` | string | `"LRS"` | `LRS`, `ZRS`, `GRS`, or `RAGRS` |
| `enable_nfs_storage_class` | bool | `false` | Create an NFS StorageClass (requires `Premium` tier) |
| `smb_storage_class_name` | string | `"azurefile-smb"` | Name of the SMB StorageClass |
| `nfs_storage_class_name` | string | `"azurefile-nfs"` | Name of the NFS StorageClass |
| `tags` | map(string) | `{}` | Tags applied to Azure resources |

## Outputs

| Output | Description |
|--------|-------------|
| `storage_account_id` | Resource ID of the Azure Storage Account |
| `storage_account_name` | Name of the storage account |
| `storage_account_primary_endpoint` | Primary file service endpoint |
| `smb_storage_class` | Name of the SMB StorageClass (`azurefile-smb`) |
| `nfs_storage_class` | Name of the NFS StorageClass (empty when disabled) |
| `smb_secret_name` | Name of the Kubernetes SMB credentials secret |

## Usage

```hcl
module "aks_addons_azure_files_csi" {
  source = "../../../terraform-modules/azure/aks-addons/azure-files-csi"

  cluster_name               = module.aks.cluster_name
  resource_group_name        = module.aks.resource_group_name
  location                   = "eastus"
  subscription_id            = "00000000-0000-0000-0000-000000000001"
  environment                = "dev"
  oidc_issuer_url            = module.aks.oidc_issuer_url
  kubelet_identity_object_id = module.aks.kubelet_identity_object_id

  storage_account_name             = "devaksfiles001"
  storage_account_tier             = "Standard"
  storage_account_replication_type = "LRS"

  enable_nfs_storage_class = false

  tags = { Environment = "dev" }
}
```

## StorageClass Examples

### Dynamic SMB PVC (ReadWriteMany)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-data
spec:
  accessModes: [ReadWriteMany]
  storageClassName: azurefile-smb
  resources:
    requests:
      storage: 10Gi
```

### NFS StorageClass (Premium tier required)

Set `enable_nfs_storage_class = true` and `storage_account_tier = "Premium"`. Then use `storageClassName: azurefile-nfs` in PVC specs.

## Dependencies

- **core** — metrics-server and base addons should be deployed first
