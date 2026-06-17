Production-grade **multi-cloud** infrastructure managed with **Terraform** modules and **Terragrunt** for DRY, hierarchical configuration. Covers a complete AWS EKS stack and an Azure AKS stack — networking, cluster, database, and all cluster addons.

## Architecture

### AWS — eci-dev / us-east-1 / dev

```
AWS Account eci-dev / us-east-1 / dev
┌─────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                          │
│  ├── Public subnets  (3× AZ)                │
│  ├── Private subnets (3× AZ, EKS nodes)     │
│  └── Database subnets (3× AZ, RDS)          │
│                                             │
│  EKS Cluster: dev-eks (k8s 1.36)            │
│  ├── Node group: 2× t3.medium               │
│  └── EKS Addons                             │
│      ├── core        (CoreDNS, kube-proxy,  │
│      │                vpc-cni, metrics-svr) │
│      ├── lb-controller  (ALB Ingress)       │
│      ├── cluster-autoscaler                 │
│      ├── ebs-csi     (gp3 StorageClass)     │
│      ├── secret-store-csi (Secrets Manager) │
│      └── pod-identity-s3  (S3 access)       │
│                                             │
│  RDS: MySQL 8.0 (dev-mysql)                 │
│  Secrets Manager: dev/rds/credentials       │
└─────────────────────────────────────────────┘
```

### Azure — eci-dev / eastus / dev

```
Azure Subscription eci-dev / eastus / dev
┌─────────────────────────────────────────────┐
│  VNet (10.0.0.0/8)                          │
│  ├── aks subnet       (10.0.0.0/16)         │
│  ├── database subnet  (10.1.0.0/24)         │
│  └── privatelink subnet (10.1.1.0/24)       │
│                                             │
│  AKS Cluster: dev-aks (k8s 1.32)            │
│  ├── System node pool: 2× Standard_D2s_v3   │
│  ├── General node pool: 2× Standard_D2s_v3  │
│  └── AKS Addons                             │
│      ├── core               (metrics-server)│
│      ├── ingress-nginx      (NGINX Ingress) │
│      ├── cluster-autoscaler                 │
│      ├── key-vault-csi      (Key Vault CSI) │
│      └── workload-identity-blob (Blob SA)   │
│                                             │
│  MySQL Flexible Server: dev-mysql           │
│  Key Vault: dev-kv                          │
└─────────────────────────────────────────────┘
```

## Repository Structure

```
terraform-by-copilot/
├── terraform-modules/
│   ├── aws/                            # Reusable AWS Terraform modules
│   │   ├── vpc/                        # VPC, subnets, NAT, IGW
│   │   ├── eks/                        # EKS cluster + node groups
│   │   ├── rds/                        # RDS MySQL + Secrets Manager
│   │   └── eks-addons/                 # EKS addon sub-modules
│   │       ├── core/                   # CoreDNS, kube-proxy, vpc-cni, metrics-server
│   │       ├── lb-controller/          # AWS Load Balancer Controller
│   │       ├── cluster-autoscaler/
│   │       ├── ebs-csi/                # EBS CSI Driver + gp3 StorageClass
│   │       ├── secret-store-csi/       # Secrets Store CSI + RDS credentials
│   │       └── pod-identity-s3/        # S3 access via Pod Identity
│   │
│   └── azure/                          # Reusable Azure Terraform modules
│       ├── vnet/                       # VNet, subnets
│       ├── aks/                        # AKS cluster + node pools
│       ├── mysql/                      # MySQL Flexible Server
│       └── aks-addons/                 # AKS addon sub-modules
│           ├── core/                   # metrics-server
│           ├── ingress-nginx/          # NGINX Ingress Controller
│           ├── cluster-autoscaler/
│           ├── key-vault-csi/          # Azure Key Vault + CSI
│           └── workload-identity-blob/ # Workload Identity + Blob Storage
│
└── terragrunt/
    ├── aws/
    │   ├── terragrunt.hcl              # AWS root config (provider + S3 backend)
    │   ├── eci-dev/
    │   │   ├── account.hcl             # aws_account_id, account_name
    │   │   └── us-east-1/
    │   │       ├── region.hcl
    │   │       └── dev/
    │   │           ├── env.hcl
    │   │           ├── vpc/
    │   │           ├── eks/
    │   │           ├── rds/
    │   │           └── eks-addons/
    │   │               ├── core/
    │   │               ├── lb-controller/
    │   │               ├── cluster-autoscaler/
    │   │               ├── ebs-csi/
    │   │               ├── secret-store-csi/
    │   │               └── pod-identity-s3/
    │   └── eci-prod/
    │       └── account.hcl
    └── azure/
        ├── terragrunt.hcl              # Azure root config (provider + AzureRM backend)
        └── eci-dev/
            ├── account.hcl             # subscription_id, tenant_id, state storage
            └── eastus/
                ├── region.hcl
                └── dev/
                    ├── env.hcl
                    ├── vnet/
                    ├── aks/
                    ├── mysql/
                    └── aks-addons/
                        ├── core/
                        ├── ingress-nginx/
                        ├── cluster-autoscaler/
                        ├── key-vault-csi/
                        └── workload-identity-blob/
```

## Terragrunt Hierarchy

Each cloud has its own root `terragrunt.hcl` that generates the provider and backend. Child configs inherit via `find_in_parent_folders()`:

```
cloud/account-name/region/env/component/terragrunt.hcl
       └── account.hcl
              └── region.hcl
                     └── env.hcl
```

## Prerequisites

| Tool        | Version   |
|-------------|-----------|
| Terraform   | >= 1.10.0 |
| Terragrunt  | >= 1.0.0  |
| AWS CLI     | >= 2.x    |
| Azure CLI   | >= 2.x    |
| kubectl     | >= 1.28   |
| helm        | >= 3.x    |

### AWS
- AWS profile `jenkins` configured (`~/.aws/credentials`)
- IAM role `arn:aws:iam::088317451471:role/terraform` assumable by the profile
- S3 bucket `terraform-state-088317451471` (eu-central-1) for remote state

### Azure
- `az login` or env vars `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`
- Azure Storage Account for Terraform state (configured in `account.hcl`)
- Update placeholder `subscription_id` / `tenant_id` in `terragrunt/azure/eci-dev/account.hcl`

## AWS Deployment Order

```
vpc → eks → rds
              └── eks-addons/core
                       └── lb-controller, cluster-autoscaler, ebs-csi,
                           secret-store-csi (+ rds), pod-identity-s3
```

### Apply all (AWS dev)

```bash
BASE=terragrunt/aws/eci-dev/us-east-1/dev

terragrunt apply --auto-approve --terragrunt-working-dir $BASE/vpc
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/rds
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/core
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/lb-controller
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/cluster-autoscaler
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/ebs-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/secret-store-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/eks-addons/pod-identity-s3
```

Terragrunt v1 shortcut (run from `terragrunt/aws/eci-dev/us-east-1/dev` only):

```bash
cd terragrunt/aws/eci-dev/us-east-1/dev
terragrunt run --all apply --non-interactive
```

Note: Running `terragrunt run --all` from repo root can fail because Terragrunt will also traverse unrelated cloud roots.

### Configure kubectl (AWS)

EKS admin access for developers is granted through IAM group -> assumable role -> EKS access entry.
For devops access, use role `dev-eks-devops-group-EKSAdminFullAccessRole`.
Ensure IAM user `amit` is a member of IAM group `devops` before running kubeconfig update.

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name dev-eks \
  --role-arn arn:aws:iam::088317451471:role/dev-eks-devops-group-EKSAdminFullAccessRole \
  --profile amit
```

If role assumption fails, add membership (from an admin profile):

```bash
aws iam add-user-to-group --group-name devops --user-name amit --profile jenkins
```

If `jenkins` gets `AccessDenied` for direct IAM calls (for example `iam:GetGroup`),
assume the Terraform admin role first, then run IAM operations with temporary credentials:

```bash
CREDS=$(aws sts assume-role \
  --role-arn arn:aws:iam::088317451471:role/terraform \
  --role-session-name iam-admin \
  --profile jenkins)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

aws iam add-user-to-group --group-name devops --user-name amit
aws iam get-group --group-name devops --query 'Users[].UserName' --output text
```

After IAM admin commands, clear temporary credentials before testing kubectl as `amit`:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_PROFILE=amit
```

## Azure Deployment Order

```
vnet → aks → mysql
               └── aks-addons/core
                        └── ingress-nginx, cluster-autoscaler,
                            key-vault-csi, workload-identity-blob
```

### Apply all (Azure dev)

```bash
BASE=terragrunt/azure/eci-dev/eastus/dev

terragrunt apply --auto-approve --terragrunt-working-dir $BASE/vnet
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/mysql
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/core
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/ingress-nginx
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/cluster-autoscaler
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/key-vault-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/workload-identity-blob
```

### Configure kubectl (Azure)

```bash
az aks get-credentials \
  --resource-group dev-aks-rg \
  --name dev-aks
```

## Remote State

### AWS
| Setting     | Value                                         |
|-------------|-----------------------------------------------|
| Bucket      | `terraform-state-088317451471`                |
| Region      | `eu-central-1`                                |
| Key pattern | `eci-dev/us-east-1/dev/<component>/terraform.tfstate` |
| Locking     | Native S3 (`use_lockfile = true`)             |

### Azure
| Setting              | Value                                         |
|----------------------|-----------------------------------------------|
| Storage Account      | `tfstateecidevstorage` (set in `account.hcl`) |
| Container            | `tfstate`                                     |
| Key pattern          | `azure/eci-dev/eastus/dev/<component>/terraform.tfstate` |

## IAM / Identity Pattern

| Cloud | Pattern | Description |
|-------|---------|-------------|
| AWS   | EKS Pod Identity | IAM role with `pods.eks.amazonaws.com` trust; no OIDC required |
| Azure | Workload Identity | Federated credential on User-Assigned Managed Identity via OIDC issuer |

## Troubleshooting

- AWS LB Controller / IngressClass conflict:
  - Symptom: `ingressclasses.networking.k8s.io "alb" already exists`
  - Cause: `alb` IngressClass is managed by the Helm chart.
  - Fix: Do not define a separate Terraform `kubernetes_ingress_class_v1.alb` resource in this module.

- State lock conflicts after interrupted runs:
  - Symptom: S3 lock errors with `StatusCode: 412` and `Lock Info`.
  - Fix: run `terragrunt force-unlock -force <LOCK_ID>` in the affected module directory, then re-run apply.

- Non-interactive apply hanging/cancelled:
  - Use `terragrunt apply -auto-approve --non-interactive` for module-level runs.

- `kubectl` still shows `AccessDenied` after role/group fixes:
  - Symptom: caller appears as an assumed admin role instead of IAM user `amit`.
  - Cause: temporary `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` are still exported.
  - Fix: `unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN` and set `AWS_PROFILE=amit` again.

## Module Documentation

### AWS
| Module | README |
|--------|--------|
| VPC | [terraform-modules/aws/vpc/README.md](terraform-modules/aws/vpc/README.md) |
| EKS | [terraform-modules/aws/eks/README.md](terraform-modules/aws/eks/README.md) |
| RDS | [terraform-modules/aws/rds/README.md](terraform-modules/aws/rds/README.md) |
| EKS Addons | [terraform-modules/aws/eks-addons/README.md](terraform-modules/aws/eks-addons/README.md) |

### Azure
| Module | README |
|--------|--------|
| Azure Modules | [terraform-modules/azure/README.md](terraform-modules/azure/README.md) |
| VNet | [terraform-modules/azure/vnet/README.md](terraform-modules/azure/vnet/README.md) |
| AKS | [terraform-modules/azure/aks/README.md](terraform-modules/azure/aks/README.md) |
| MySQL | [terraform-modules/azure/mysql/README.md](terraform-modules/azure/mysql/README.md) |
| AKS Addons | [terraform-modules/azure/aks-addons/README.md](terraform-modules/azure/aks-addons/README.md) |

## References

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/docs/)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)

