include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/azure/aks-addons/workload-identity-blob"
}

locals {
  account_vars    = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars     = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars        = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  subscription_id = local.account_vars.locals.subscription_id
  tenant_id       = local.account_vars.locals.tenant_id
  azure_region    = local.region_vars.locals.azure_region
  environment     = local.env_vars.locals.environment
}

dependency "aks" {
  config_path = "../../aks"
  mock_outputs = {
    cluster_name        = "dev-aks"
    resource_group_name = "dev-aks-rg"
    oidc_issuer_url     = "https://mock.oidc.example.com/"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "core" {
  config_path = "../core"
  mock_outputs = {
    metrics_server_status = "deployed"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name        = dependency.aks.outputs.cluster_name
  resource_group_name = dependency.aks.outputs.resource_group_name
  location            = local.azure_region
  subscription_id     = local.subscription_id
  tenant_id           = local.tenant_id
  environment         = local.environment
  oidc_issuer_url     = dependency.aks.outputs.oidc_issuer_url

  # Azure Blob Storage container to grant access to
  storage_account_name   = "${local.environment}appblobstorage"
  storage_resource_group = "${local.environment}-data-rg"
  blob_container_name    = "app-data"

  # Kubernetes service account that will assume the identity (Workload Identity)
  # equivalent to AWS EKS Pod Identity
  service_account_name      = "blob-access-sa"
  service_account_namespace = "default"

  # Azure User-Assigned Managed Identity name
  managed_identity_name = "${local.environment}-blob-access-identity"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
