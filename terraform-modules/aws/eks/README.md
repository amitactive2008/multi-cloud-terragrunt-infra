# AWS EKS Module

Creates an EKS cluster with managed node groups, a cluster security group, a node security group, and an OIDC provider for IRSA (IAM Roles for Service Accounts).

## Architecture

```
EKS Cluster
├── IAM Role (cluster)        — AmazonEKSClusterPolicy, AmazonEKSVPCResourceController
├── IAM Role (nodes)          — AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy,
│                               AmazonEC2ContainerRegistryReadOnly
├── Security Group (cluster)  — control plane
├── Security Group (nodes)    — worker nodes; allows node↔node + node↔control-plane
├── EKS Cluster               — Kubernetes 1.35, private+public endpoint
├── OIDC Provider             — enables IRSA / Pod Identity
└── Managed Node Groups       — configurable per-group (instance type, size, taints, labels)
```

## Usage

```hcl
module "eks" {
  source = "../../terraform-modules/aws/eks"

  cluster_name = "prod-eks"
  vpc_id       = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids

  node_groups = {
    default = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      disk_size_gb   = 50
      capacity_type  = "ON_DEMAND"
    }
    spot = {
      instance_types = ["t3.large", "t3a.large"]
      desired_size   = 0
      min_size       = 0
      max_size       = 10
      capacity_type  = "SPOT"
      labels         = { workload = "batch" }
    }
  }

  tags = {
    Environment = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `cluster_name` | Name of the EKS cluster | `string` | — | yes |
| `kubernetes_version` | Kubernetes version | `string` | `"1.35"` | no |
| `vpc_id` | VPC ID where the cluster is deployed | `string` | — | yes |
| `private_subnet_ids` | Private subnet IDs for node groups (min 2 AZs) | `list(string)` | — | yes |
| `node_groups` | Map of managed node group configurations | `map(object)` | 1 default group (t3.medium ×2) | no |
| `cluster_endpoint_private_access` | Enable private API endpoint | `bool` | `true` | no |
| `cluster_endpoint_public_access` | Enable public API endpoint | `bool` | `true` | no |
| `cluster_endpoint_public_access_cidrs` | CIDRs allowed for public endpoint access | `list(string)` | `["0.0.0.0/0"]` | no |
| `enabled_cluster_log_types` | Control-plane log types to enable | `list(string)` | all 5 types | no |
| `tags` | Additional tags | `map(string)` | `{}` | no |

### `node_groups` object schema

```hcl
{
  instance_types = list(string)           # e.g. ["t3.medium"]
  desired_size   = number
  min_size       = number
  max_size       = number
  disk_size_gb   = optional(number, 50)
  capacity_type  = optional(string, "ON_DEMAND")  # ON_DEMAND | SPOT
  labels         = optional(map(string), {})
  taints = optional(list(object({
    key    = string
    value  = string
    effect = string                       # NO_SCHEDULE | NO_EXECUTE | PREFER_NO_SCHEDULE
  })), [])
}
```

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | EKS cluster name |
| `cluster_id` | EKS cluster ID |
| `cluster_arn` | EKS cluster ARN |
| `cluster_endpoint` | API server endpoint URL |
| `cluster_version` | Kubernetes version |
| `cluster_certificate_authority` | Base64-encoded CA certificate |
| `cluster_security_group_id` | Control-plane security group ID |
| `node_security_group_id` | Node security group ID |
| `cluster_iam_role_arn` | Cluster IAM role ARN |
| `node_iam_role_arn` | Node IAM role ARN |
| `oidc_provider_arn` | OIDC provider ARN (for IRSA) |
| `oidc_provider_url` | OIDC provider URL |

## Configure kubectl

```bash
aws eks update-kubeconfig \
  --name <cluster_name> \
  --region <aws_region> \
  --role-arn arn:aws:iam::<account_id>:role/terraform
```

## Terragrunt example

See [`terragrunt/aws/088317451471/us-east-1/dev/eks/terragrunt.hcl`](../../../terragrunt/aws/088317451471/us-east-1/dev/eks/terragrunt.hcl).
