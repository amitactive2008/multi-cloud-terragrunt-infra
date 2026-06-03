# AWS VPC Module

Creates a production-ready VPC with public, private, DB, and ES subnet tiers across two Availability Zones, a NAT Gateway, and all required route tables.

## Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets      (AZ-a, AZ-b)  — internet-facing, ALB placement
├── Private Subnets     (AZ-a, AZ-b)  — EKS worker nodes
├── DB Subnets          (AZ-a, AZ-b)  — RDS, ElastiCache
├── ES Subnets          (AZ-a, AZ-b)  — OpenSearch / Elasticsearch
├── Internet Gateway    — public subnet egress/ingress
└── NAT Gateway         — single, in first public subnet (private egress)
```

When `eks_cluster_name` is set, the module tags subnets for ALB/NLB auto-discovery:

| Subnet tier | Tag added |
|---|---|
| Public | `kubernetes.io/role/elb = 1` |
| Private | `kubernetes.io/role/internal-elb = 1` |
| Both | `kubernetes.io/cluster/<cluster-name> = shared` |

## Usage

```hcl
module "vpc" {
  source = "../../terraform-modules/aws/vpc"

  name       = "prod-vpc"
  cidr_block = "10.0.0.0/16"

  azs = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  db_subnet_cidrs      = ["10.0.21.0/24", "10.0.22.0/24"]
  es_subnet_cidrs      = ["10.0.31.0/24", "10.0.32.0/24"]

  # Required when EKS + ALB/NLB are deployed in this VPC
  eks_cluster_name = "prod-eks"

  tags = {
    Environment = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `name` | Name prefix for all resources | `string` | — | yes |
| `cidr_block` | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| `azs` | Exactly 2 Availability Zones | `list(string)` | — | yes |
| `public_subnet_cidrs` | CIDRs for public subnets (one per AZ) | `list(string)` | `["10.0.1.0/24","10.0.2.0/24"]` | no |
| `private_subnet_cidrs` | CIDRs for private subnets (one per AZ) | `list(string)` | `["10.0.11.0/24","10.0.12.0/24"]` | no |
| `db_subnet_cidrs` | CIDRs for DB subnets (one per AZ) | `list(string)` | `["10.0.21.0/24","10.0.22.0/24"]` | no |
| `es_subnet_cidrs` | CIDRs for ES subnets (one per AZ) | `list(string)` | `["10.0.31.0/24","10.0.32.0/24"]` | no |
| `eks_cluster_name` | EKS cluster name for subnet ALB/NLB tags | `string` | `""` | no |
| `tags` | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `vpc_cidr_block` | CIDR block of the VPC |
| `public_subnet_ids` | IDs of public subnets |
| `private_subnet_ids` | IDs of private subnets |
| `db_subnet_ids` | IDs of DB subnets |
| `es_subnet_ids` | IDs of ES subnets |
| `db_subnet_group_name` | Name of the RDS DB subnet group |
| `nat_gateway_id` | ID of the NAT Gateway |
| `internet_gateway_id` | ID of the Internet Gateway |

## Terragrunt example

See [`terragrunt/aws/088317451471/us-east-1/dev/vpc/terragrunt.hcl`](../../../terragrunt/aws/088317451471/us-east-1/dev/vpc/terragrunt.hcl).
