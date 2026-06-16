# AWS EKS Module

Creates an EKS cluster with managed node groups, a cluster security group, a node security group, and an OIDC provider for IRSA (IAM Roles for Service Accounts).

Supports group-based EKS cluster-admin access using IAM roles — members of an IAM group automatically gain cluster access without requiring a Terraform re-apply when membership changes.

## Architecture

```
EKS Cluster
├── IAM Role (cluster)          — AmazonEKSClusterPolicy, AmazonEKSVPCResourceController
├── IAM Role (nodes)            — AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy,
│                                 AmazonEC2ContainerRegistryReadOnly
├── Security Group (cluster)    — control plane
├── Security Group (nodes)      — worker nodes; allows node↔node + node↔control-plane
├── EKS Cluster                 — Kubernetes 1.35+, private+public endpoint
│   └── access_config           — authentication_mode = API_AND_CONFIG_MAP
├── OIDC Provider               — enables IRSA / Pod Identity
├── Managed Node Groups         — configurable per-group (instance type, size, taints, labels)
│   └── release_version         — auto-resolved from SSM (always latest AMI for the k8s version)
└── EKS Access Entries
    ├── Per devops_admin_groups  — one IAM role per group; group members assume it
    │   └── aws_iam_group_policy — allows members to run sts:AssumeRole
    └── Per cluster_admin_arns  — direct user/role ARNs (e.g. CI service accounts)
```

## Group-based EKS Access (Recommended)

EKS access entries do **not** support IAM groups directly. This module solves that by creating a dedicated **assumable IAM role** for each group listed in `devops_admin_groups`:

```
devops group member  →  assume devops-eks-admin role  →  EKS cluster-admin
```

**Benefits:**
- Add/remove users from the IAM group → access changes **immediately**, no `terraform apply` needed
- Follows AWS best practice: users assume roles, not direct access
- Works with AWS Console "Switch Role" and `aws sts assume-role` in CI

**How group members access the cluster:**

### AWS Console (UI)

1. Log in to the AWS Console as your IAM user (e.g. `amit`)
2. Click your account name in the top-right corner → **Switch role**
3. Fill in the form:
   | Field | Value |
   |---|---|
   | **Account** | `088317451471` |
   | **Role** | `devops-eks-admin` |
   | **Display name** | `EKS Admin` *(optional label)* |
4. Click **Switch Role** — the console session now runs under `devops-eks-admin`
5. Navigate to **EKS → Clusters → dev-eks**
   - The "doesn't have access" warning is gone
   - All tabs (Nodes, Workloads, Config, etc.) are fully accessible

> **Tip:** After switching once, the role appears in the account switcher history — one click on future logins.

### CLI (kubectl)

```bash
# Update kubeconfig to use the devops-eks-admin role
aws eks update-kubeconfig \
  --name <cluster_name> \
  --region <aws_region> \
  --role-arn arn:aws:iam::<account_id>:role/devops-eks-admin --profile default

# Verify access
kubectl get nodes
kubectl get pods -A
```

## Usage

```hcl
module "eks" {
  source = "../../terraform-modules/aws/eks"

  cluster_name       = "prod-eks"
  account_id         = "123456789012"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      disk_size_gb   = 50
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD"  # latest AMI auto-resolved
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

  # All members of the 'devops' IAM group get cluster-admin via an assumable role.
  # No re-apply needed when group membership changes.
  devops_admin_groups = ["devops"]

  # Individual users/roles that also need cluster-admin (e.g. CI service accounts).
  cluster_admin_arns = [
    "arn:aws:iam::123456789012:user/jenkins",
  ]

  tags = {
    Environment = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `cluster_name` | Name of the EKS cluster | `string` | — | yes |
| `account_id` | AWS account ID | `string` | — | yes |
| `kubernetes_version` | Kubernetes version | `string` | `"1.35"` | no |
| `vpc_id` | VPC ID where the cluster is deployed | `string` | — | yes |
| `private_subnet_ids` | Private subnet IDs for node groups (min 2 AZs) | `list(string)` | — | yes |
| `node_groups` | Map of managed node group configurations | `map(object)` | 1 default group (t3.medium ×2) | no |
| `devops_admin_groups` | IAM group names whose members get cluster-admin via an assumable role | `list(string)` | `[]` | no |
| `cluster_admin_arns` | Additional user/role ARNs to grant cluster-admin directly | `list(string)` | `[]` | no |
| `authentication_mode` | EKS auth mode (`API_AND_CONFIG_MAP` or `API`) | `string` | `"API_AND_CONFIG_MAP"` | no |
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
  capacity_type  = optional(string, "ON_DEMAND")           # ON_DEMAND | SPOT
  ami_type       = optional(string, "AL2023_x86_64_STANDARD")  # see below
  labels         = optional(map(string), {})
  taints = optional(list(object({
    key    = string
    value  = string
    effect = string                       # NO_SCHEDULE | NO_EXECUTE | PREFER_NO_SCHEDULE
  })), [])
}
```

**Supported `ami_type` values:**

| Value | Description |
|---|---|
| `AL2023_x86_64_STANDARD` | Amazon Linux 2023, x86_64 (default) |
| `AL2023_ARM_64_STANDARD` | Amazon Linux 2023, ARM64 (Graviton) |
| `AL2_x86_64` | Amazon Linux 2, x86_64 |
| `AL2_x86_64_GPU` | Amazon Linux 2, x86_64 with GPU drivers |

The latest AMI release version for the selected `kubernetes_version` is automatically resolved from SSM Parameter Store on every `terraform apply`.

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
| `devops_eks_admin_role_arns` | Map of `group-name => role ARN` for group-based access |

## Configure kubectl

```bash
# Using the devops admin role (for group members):
aws eks update-kubeconfig \
  --name <cluster_name> \
  --region <aws_region> \
  --role-arn arn:aws:iam::<account_id>:role/devops-eks-admin

# Using the terraform automation role:
aws eks update-kubeconfig \
  --name <cluster_name> \
  --region <aws_region> \
  --role-arn arn:aws:iam::<account_id>:role/terraform
```

## Terragrunt example

See [terragrunt/aws/eci-dev/us-east-1/dev/eks/terragrunt.hcl](../../../terragrunt/aws/eci-dev/us-east-1/dev/eks/terragrunt.hcl).


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
