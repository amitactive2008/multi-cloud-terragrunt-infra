# terraform-modules/azure/aks

Creates an AKS cluster with a system node pool, optional user node pools, and production-ready settings: Azure CNI networking, OIDC issuer, Azure Workload Identity, and Key Vault Secrets Provider.

## Resources Created

| Resource | Description |
|----------|-------------|
| `azurerm_resource_group` | Resource group for the cluster |
| `azurerm_kubernetes_cluster` | AKS cluster with system node pool |
| `azurerm_kubernetes_cluster_node_pool` (×N) | User node pools (one per `var.user_node_pools` entry) |

## Usage

```hcl
module "aks" {
  source              = "../../terraform-modules/azure/aks"
  cluster_name        = "dev-aks"
  resource_group_name = "dev-aks-rg"
  location            = "eastus"
  kubernetes_version  = "1.32"

  vnet_id       = module.vnet.vnet_id
  aks_subnet_id = module.vnet.aks_subnet_id

  system_node_pool = {
    name                = "system"
    vm_size             = "Standard_D2s_v3"
    node_count          = 2
    min_count           = 1
    max_count           = 5
    enable_auto_scaling = true
    os_disk_size_gb     = 50
  }

  user_node_pools = {
    general = {
      name                = "general"
      vm_size             = "Standard_D2s_v3"
      node_count          = 2
      min_count           = 1
      max_count           = 10
      enable_auto_scaling = true
      os_disk_size_gb     = 50
    }
  }

  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  key_vault_secrets_provider_enabled = true

  tags = { Environment = "dev", ManagedBy = "terraform" }
}
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `cluster_name` | `string` | yes | AKS cluster name |
| `resource_group_name` | `string` | yes | Resource group name (created by this module) |
| `location` | `string` | yes | Azure region |
| `kubernetes_version` | `string` | yes | Kubernetes version |
| `sku_tier` | `string` | no | `Free`, `Standard`, or `Premium` (default: `Free`) |
| `vnet_id` | `string` | yes | VNet ID |
| `aks_subnet_id` | `string` | yes | Subnet ID for node pools |
| `system_node_pool` | `object` | yes | Default system node pool config |
| `user_node_pools` | `map(object)` | no | Additional user node pools |
| `network_plugin` | `string` | no | `azure` or `kubenet` (default: `azure`) |
| `network_policy` | `string` | no | `azure`, `calico`, or `cilium` (default: `azure`) |
| `oidc_issuer_enabled` | `bool` | no | Enable OIDC issuer (default: `true`) |
| `workload_identity_enabled` | `bool` | no | Enable Workload Identity (default: `true`) |
| `key_vault_secrets_provider_enabled` | `bool` | no | Enable Key Vault CSI addon (default: `true`) |
| `api_server_authorized_ip_ranges` | `list(string)` | no | Allowed API server IPs. `[]` = unrestricted |
| `tags` | `map(string)` | no | Tags applied to all resources |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | AKS cluster name |
| `cluster_id` | AKS cluster resource ID |
| `resource_group_name` | Cluster resource group |
| `kube_config_raw` | Raw kubeconfig (sensitive) |
| `oidc_issuer_url` | OIDC issuer URL — required by Workload Identity addon modules |
| `node_resource_group` | Auto-created node resource group (MC_…) |
| `kubelet_identity_client_id` | Client ID of the kubelet managed identity |
| `kubelet_identity_object_id` | Object ID of the kubelet managed identity |

## Identity Pattern

This module uses a **SystemAssigned** identity for the cluster itself. Workloads use **Azure Workload Identity** via federated credentials (see `aks-addons/workload-identity-blob`). This is Azure's equivalent of AWS EKS Pod Identity — no service principal secrets are stored in state.

## Configure kubectl

```bash
az aks get-credentials \
  --resource-group dev-aks-rg \
  --name dev-aks
```
