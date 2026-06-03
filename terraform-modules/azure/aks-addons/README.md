# terraform-modules/azure/aks-addons

Independent addon modules for AKS. Each sub-module manages a specific concern and has its own Terraform state. They mirror the AWS `eks-addons` pattern.

## Sub-modules

| Module | AWS Equivalent | Description |
|--------|---------------|-------------|
| [core/](core/README.md) | `eks-addons/core` | metrics-server Helm chart |
| [ingress-nginx/](ingress-nginx/README.md) | `eks-addons/lb-controller` | NGINX Ingress Controller (replaces ALB) |
| [cluster-autoscaler/](cluster-autoscaler/README.md) | `eks-addons/cluster-autoscaler` | Kubernetes Cluster Autoscaler |
| [key-vault-csi/](key-vault-csi/README.md) | `eks-addons/secret-store-csi` | Azure Key Vault + CSI Secret Provider |
| [workload-identity-blob/](workload-identity-blob/README.md) | `eks-addons/pod-identity-s3` | Workload Identity for Blob Storage access |

## Dependency Order

```
core  ← must be applied first
  ↓
  ├── ingress-nginx
  ├── cluster-autoscaler
  ├── key-vault-csi
  └── workload-identity-blob
```

## Identity Pattern

All addons that require Azure permissions use **Azure Workload Identity** — OIDC federated credentials on a User-Assigned Managed Identity. The Kubernetes service account is annotated with `azure.workload.identity/client-id`. No service principal secrets are stored anywhere.

This is functionally equivalent to AWS EKS Pod Identity.

## Common Inputs

All addon modules require:

| Variable | Description |
|----------|-------------|
| `cluster_name` | AKS cluster name (from `dependency.aks.outputs.cluster_name`) |
| `resource_group_name` | Cluster resource group |
| `location` | Azure region |
| `subscription_id` | Azure subscription ID |
| `environment` | Environment name |
| `oidc_issuer_url` | OIDC issuer URL (from `dependency.aks.outputs.oidc_issuer_url`) |
