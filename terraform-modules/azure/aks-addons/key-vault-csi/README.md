# terraform-modules/azure/aks-addons/key-vault-csi

Creates an **Azure Key Vault** and grants the AKS kubelet identity the `Key Vault Secrets User` RBAC role. AKS already ships the Key Vault Secrets Provider addon built-in (enabled by `key_vault_secrets_provider_enabled = true` in the AKS module); this module provisions the vault itself and the access policy.

This is the Azure equivalent of `eks-addons/secret-store-csi`.

## Resources Created

| Resource | Description |
|----------|-------------|
| `azurerm_resource_group` | Resource group for the Key Vault |
| `azurerm_key_vault` | Azure Key Vault with RBAC authorization enabled |
| `azurerm_role_assignment` | Grants kubelet identity `Key Vault Secrets User` role |

## Usage

```hcl
module "key_vault_csi" {
  source              = "../../terraform-modules/azure/aks-addons/key-vault-csi"
  cluster_name        = "dev-aks"
  resource_group_name = "dev-aks-rg"
  location            = "eastus"
  subscription_id     = "00000000-…"
  tenant_id           = "00000000-…"
  environment         = "dev"
  oidc_issuer_url     = "https://…"

  key_vault_name              = "dev-kv"
  key_vault_resource_group    = "dev-kv-rg"
  kubelet_identity_object_id  = "…"
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
| `oidc_issuer_url` | `string` | — | OIDC issuer URL |
| `key_vault_name` | `string` | — | Name of the Key Vault (3-24 chars, globally unique) |
| `key_vault_resource_group` | `string` | — | Resource group for the Key Vault |
| `key_vault_sku` | `string` | `standard` | Key Vault SKU |
| `soft_delete_retention_days` | `number` | `7` | Days to retain deleted secrets |
| `purge_protection_enabled` | `bool` | `false` | Prevent hard-deletion |
| `kubelet_identity_object_id` | `string` | — | Object ID of AKS kubelet identity |
| `tags` | `map(string)` | `{}` | Tags |

## Outputs

| Name | Description |
|------|-------------|
| `key_vault_id` | Key Vault resource ID |
| `key_vault_name` | Key Vault name |
| `key_vault_uri` | Key Vault URI (for `SecretProviderClass`) |

## Using Secrets in Pods

After applying this module, create a `SecretProviderClass` in Kubernetes:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-secrets
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "<kubelet_identity_client_id>"
    keyvaultName: "dev-kv"
    tenantId: "<tenant_id>"
    objects: |
      array:
        - |
          objectName: my-secret
          objectType: secret
```
