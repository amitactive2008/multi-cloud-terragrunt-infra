# Terragrunt — Azure dev environment

Terragrunt configurations for the `dev` environment in Azure account `eci-dev`, region `eastus`.

## Components

| Directory | Module | Description |
|-----------|--------|-------------|
| `vnet/` | `terraform-modules/azure/vnet` | VNet, subnets (AKS, database, private link) |
| `aks/` | `terraform-modules/azure/aks` | AKS cluster + node pools, Workload Identity |
| `mysql/` | `terraform-modules/azure/mysql` | MySQL Flexible Server + private DNS |
| `aks-addons/` | `terraform-modules/azure/aks-addons/*` | All AKS addon sub-modules |

## Deployment Order

```
vnet
 └── aks
      └── mysql
           └── aks-addons/core
                    └── aks-addons/{ingress-nginx,cluster-autoscaler,key-vault-csi,workload-identity-blob}
```

## Apply All

```bash
BASE=$(pwd)

terragrunt apply --auto-approve --terragrunt-working-dir $BASE/vnet
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/mysql
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/core
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/ingress-nginx
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/cluster-autoscaler
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/key-vault-csi
terragrunt apply --auto-approve --terragrunt-working-dir $BASE/aks-addons/workload-identity-blob
```

## Destroy All (reverse order)

```bash
BASE=$(pwd)

for dir in \
  aks-addons/workload-identity-blob \
  aks-addons/key-vault-csi \
  aks-addons/cluster-autoscaler \
  aks-addons/ingress-nginx \
  aks-addons/core \
  mysql \
  aks \
  vnet; do
  terragrunt destroy --auto-approve --terragrunt-working-dir $BASE/$dir
done
```

## Configure kubectl

```bash
az aks get-credentials \
  --resource-group dev-aks-rg \
  --name dev-aks
```

## Environment Variables

Inherited from parent `env.hcl`:
- `environment = "dev"`

Inherited from `region.hcl`:
- `azure_region = "eastus"`

Inherited from `account.hcl`:
- `subscription_id` — replace placeholder with real Azure subscription ID
- `tenant_id` — replace placeholder with real Azure tenant ID
- `state_storage_account = "tfstateecidevstorage"`
- `state_resource_group = "terraform-state-rg"`

## Before First Deploy

1. Update `terragrunt/azure/eci-dev/account.hcl` with real `subscription_id` and `tenant_id`
2. Create the Azure Storage Account and container for Terraform state:
   ```bash
   az group create --name terraform-state-rg --location eastus
   az storage account create \
     --name tfstateecidevstorage \
     --resource-group terraform-state-rg \
     --location eastus \
     --sku Standard_LRS
   az storage container create \
     --name tfstate \
     --account-name tfstateecidevstorage
   ```
3. Authenticate: `az login` or set `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`
