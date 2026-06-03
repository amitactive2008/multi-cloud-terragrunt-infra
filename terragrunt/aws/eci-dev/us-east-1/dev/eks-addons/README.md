# Terragrunt — EKS Addons (dev)

Terragrunt configurations for all EKS addon sub-modules in the `dev` environment. Each subdirectory is an independent deployable unit with its own Terraform state.

## Structure

```
eks-addons/
├── core/                 # CoreDNS, kube-proxy, vpc-cni, metrics-server
├── lb-controller/        # AWS Load Balancer Controller + ALB IngressClass
├── cluster-autoscaler/   # Kubernetes Cluster Autoscaler
├── ebs-csi/              # EBS CSI Driver + gp3 StorageClass
├── secret-store-csi/     # Secrets Store CSI + RDS credential mount
└── pod-identity-s3/      # S3 access via Pod Identity
```

## Dependency Order

```
core  ←  must be applied first (deploys Pod Identity Agent)
  ↓
  ├── lb-controller
  ├── cluster-autoscaler
  ├── ebs-csi
  ├── secret-store-csi   (also depends on: ../../rds)
  └── pod-identity-s3
```

## Apply

```bash
# From this directory:
BASE=$(pwd)

# 1. Core addons first
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/core

# 2. Remaining addons (can run in parallel after core)
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/lb-controller
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/cluster-autoscaler
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/ebs-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/secret-store-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/pod-identity-s3
```

## Destroy (reverse order)

```bash
BASE=$(pwd)

terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/lb-controller
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/cluster-autoscaler
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/ebs-csi
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/secret-store-csi
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/pod-identity-s3
terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/core
```

## State Locations (S3)

| Module | S3 Key |
|--------|--------|
| core | `eci-dev/us-east-1/dev/eks-addons/core/terraform.tfstate` |
| lb-controller | `eci-dev/us-east-1/dev/eks-addons/lb-controller/terraform.tfstate` |
| cluster-autoscaler | `eci-dev/us-east-1/dev/eks-addons/cluster-autoscaler/terraform.tfstate` |
| ebs-csi | `eci-dev/us-east-1/dev/eks-addons/ebs-csi/terraform.tfstate` |
| secret-store-csi | `eci-dev/us-east-1/dev/eks-addons/secret-store-csi/terraform.tfstate` |
| pod-identity-s3 | `eci-dev/us-east-1/dev/eks-addons/pod-identity-s3/terraform.tfstate` |

All state is stored in the `terraform-state-088317451471` bucket (eu-central-1).

State keys are relative to `terragrunt/aws/` (the new root location).

## Terraform Module Sources

| Module | Source |
|--------|--------|
| core | `terraform-modules/aws/eks-addons/core` |
| lb-controller | `terraform-modules/aws/eks-addons/lb-controller` |
| cluster-autoscaler | `terraform-modules/aws/eks-addons/cluster-autoscaler` |
| ebs-csi | `terraform-modules/aws/eks-addons/ebs-csi` |
| secret-store-csi | `terraform-modules/aws/eks-addons/secret-store-csi` |
| pod-identity-s3 | `terraform-modules/aws/eks-addons/pod-identity-s3` |
