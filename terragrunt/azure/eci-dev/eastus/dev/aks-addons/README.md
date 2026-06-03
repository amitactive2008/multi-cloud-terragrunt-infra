# Terragrunt — AKS Addons (Azure dev)

Terragrunt configurations for all AKS addon sub-modules in the `dev` environment. Each subdirectory is an independent deployable unit with its own Terraform state.

## Structure

```
aks-addons/
├── core/                   # metrics-server
├── ingress-nginx/          # NGINX Ingress Controller + Azure Load Balancer
├── cluster-autoscaler/     # Kubernetes Cluster Autoscaler
├── key-vault-csi/          # Azure Key Vault + CSI Secrets Provider
└── workload-identity-blob/ # Workload Identity + Blob Storage access
```

## Dependency Order

```
core  ←  must be applied first
  ↓
  ├── ingress-nginx
  ├── cluster-autoscaler
  ├── key-vault-csi
  └── workload-identity-blob
```

## Apply

```bash
BASE=$(pwd)

# 1. Core first
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/core

# 2. Remaining addons (can run in parallel after core)
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/ingress-nginx
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/cluster-autoscaler
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/key-vault-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/workload-identity-blob
```

## Destroy (reverse order)

```bash
BASE=$(pwd)

terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/workload-identity-blob
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/key-vault-csi
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/cluster-autoscaler
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/ingress-nginx
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/core
```

## State Locations (Azure Blob Storage)

| Module | State Key |
|--------|-----------|
| core | `azure/eci-dev/eastus/dev/aks-addons/core/terraform.tfstate` |
| ingress-nginx | `azure/eci-dev/eastus/dev/aks-addons/ingress-nginx/terraform.tfstate` |
| cluster-autoscaler | `azure/eci-dev/eastus/dev/aks-addons/cluster-autoscaler/terraform.tfstate` |
| key-vault-csi | `azure/eci-dev/eastus/dev/aks-addons/key-vault-csi/terraform.tfstate` |
| workload-identity-blob | `azure/eci-dev/eastus/dev/aks-addons/workload-identity-blob/terraform.tfstate` |

All state is stored in container `tfstate` of storage account `tfstateecidevstorage`.

## Terraform Module Sources

| Addon | Source |
|-------|--------|
| core | `terraform-modules/azure/aks-addons/core` |
| ingress-nginx | `terraform-modules/azure/aks-addons/ingress-nginx` |
| cluster-autoscaler | `terraform-modules/azure/aks-addons/cluster-autoscaler` |
| key-vault-csi | `terraform-modules/azure/aks-addons/key-vault-csi` |
| workload-identity-blob | `terraform-modules/azure/aks-addons/workload-identity-blob` |

## AWS ↔ Azure Equivalents

| Azure Addon | AWS Addon |
|-------------|-----------|
| ingress-nginx | lb-controller (ALB) |
| key-vault-csi | secret-store-csi (Secrets Manager) |
| workload-identity-blob | pod-identity-s3 |
| cluster-autoscaler | cluster-autoscaler |
| core (metrics-server) | core (metrics-server) |
