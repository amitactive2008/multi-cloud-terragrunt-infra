include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/azure/aks-addons/core"
}

locals {
  account_vars    = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars     = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars        = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  subscription_id = local.account_vars.locals.subscription_id
  azure_region    = local.region_vars.locals.azure_region
  environment     = local.env_vars.locals.environment
}

dependency "aks" {
  config_path = "../../aks"
  mock_outputs = {
    cluster_name        = "dev-aks"
    resource_group_name = "dev-aks-rg"
    oidc_issuer_url     = "https://mock.oidc.example.com/00000000-0000-0000-0000-000000000001/00000000-0000-0000-0000-000000000001/"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name        = dependency.aks.outputs.cluster_name
  resource_group_name = dependency.aks.outputs.resource_group_name
  location            = local.azure_region
  subscription_id     = local.subscription_id
  environment         = local.environment
  oidc_issuer_url     = dependency.aks.outputs.oidc_issuer_url

  # metrics-server Helm chart version
  metrics_server_version = "3.12.2"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
