# Terragrunt — dev environment

Terragrunt configurations for the `dev` environment in account `088317451471`, region `us-east-1`.

## Components

| Directory | Module | Description |
|-----------|--------|-------------|
| `vpc/` | `terraform-modules/aws/vpc` | VPC, subnets, NAT, IGW |
| `eks/` | `terraform-modules/aws/eks` | EKS cluster + managed node groups |
| `rds/` | `terraform-modules/aws/rds` | MySQL RDS + Secrets Manager |
| `eks-addons/` | `terraform-modules/aws/eks-addons/*` | All EKS addon sub-modules |

## Deployment Order

```
vpc
 └── eks
      └── rds
           └── eks-addons/core
                    └── eks-addons/{lb-controller,cluster-autoscaler,ebs-csi,
                                   secret-store-csi,pod-identity-s3,external-dns}
```

## Apply All

```bash
BASE=$(pwd)
export AWS_PROFILE='jenkins'
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/vpc
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/rds
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/core
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/lb-controller
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/cluster-autoscaler
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/ebs-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/secret-store-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/pod-identity-s3
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/external-dns
```

## Destroy All (reverse order)

```bash
BASE=$(pwd)

for dir in eks-addons/external-dns eks-addons/pod-identity-s3 eks-addons/secret-store-csi \
           eks-addons/ebs-csi eks-addons/cluster-autoscaler eks-addons/lb-controller \
           eks-addons/core rds eks vpc; do
  terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/$dir
done
```

## Environment Variables

Inherited from parent `env.hcl`:
- `environment = "dev"`

Inherited from `region.hcl`:
- `aws_region = "us-east-1"`

Inherited from `account.hcl`:
- `aws_account_id = "088317451471"`
