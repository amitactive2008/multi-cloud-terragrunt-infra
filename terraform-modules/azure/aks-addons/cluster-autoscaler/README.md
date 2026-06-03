# terraform-modules/azure/aks-addons/cluster-autoscaler

Deploys the standalone **Kubernetes Cluster Autoscaler** via Helm and grants the cluster identity the `Contributor` role on the node resource group so it can scale VMSS node pools.

> **Note:** AKS node pools already support auto-scaling via the native Azure autoscaler. This module deploys the Helm-based cluster-autoscaler for environments that prefer uniform configuration with other cloud providers.

## Resources Created

| Resource | Description |
|----------|-------------|
| `azurerm_role_assignment.contributor` | Grants cluster identity Contributor on node RG |
| `helm_release.cluster_autoscaler` | Cluster Autoscaler Helm chart in `kube-system` |

## Usage

```hcl
module "cluster_autoscaler" {
  source              = "../../terraform-modules/azure/aks-addons/cluster-autoscaler"
  cluster_name        = "dev-aks"
  resource_group_name = "dev-aks-rg"
  node_resource_group = "MC_dev-aks-rg_dev-aks_eastus"
  location            = "eastus"
  subscription_id     = "00000000-…"
  environment         = "dev"
  oidc_issuer_url     = "https://…"
  cluster_autoscaler_version = "9.43.2"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | `string` | — | AKS cluster name |
| `resource_group_name` | `string` | — | Cluster resource group |
| `node_resource_group` | `string` | — | Auto-created node RG (`MC_…`) |
| `location` | `string` | — | Azure region |
| `subscription_id` | `string` | — | Azure subscription ID |
| `environment` | `string` | — | Environment name |
| `oidc_issuer_url` | `string` | — | OIDC issuer URL |
| `cluster_autoscaler_version` | `string` | `9.43.2` | Helm chart version |
| `service_account_name` | `string` | `cluster-autoscaler` | K8s service account name |
| `service_account_namespace` | `string` | `kube-system` | K8s namespace |
| `tags` | `map(string)` | `{}` | Tags for Azure resources |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_autoscaler_status` | Helm release status |
