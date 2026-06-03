# terraform-modules/azure/aks-addons/core

Deploys foundational cluster-wide tooling: **metrics-server** via Helm. This module must be applied before any other addon module.

## Resources Created

| Resource | Description |
|----------|-------------|
| `helm_release.metrics_server` | metrics-server Helm chart in `kube-system` |

## Usage

```hcl
module "core" {
  source              = "../../terraform-modules/azure/aks-addons/core"
  cluster_name        = "dev-aks"
  resource_group_name = "dev-aks-rg"
  location            = "eastus"
  subscription_id     = "00000000-…"
  environment         = "dev"
  oidc_issuer_url     = "https://…"
  metrics_server_version = "3.12.2"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | `string` | — | AKS cluster name |
| `resource_group_name` | `string` | — | Cluster resource group |
| `location` | `string` | — | Azure region |
| `subscription_id` | `string` | — | Azure subscription ID |
| `environment` | `string` | — | Environment name |
| `oidc_issuer_url` | `string` | — | OIDC issuer URL from AKS |
| `metrics_server_version` | `string` | `3.12.2` | Helm chart version |
| `tags` | `map(string)` | `{}` | Tags for Azure resources |

## Outputs

| Name | Description |
|------|-------------|
| `metrics_server_status` | Helm release status (`deployed`) |
