include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/azure/aks-addons/key-vault-csi"
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
    kubelet_identity_object_id = "00000000-0000-0000-0000-000000000000"
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

  # AKS has the Key Vault Secrets Provider addon built-in — this module
  # creates the Azure Key Vault, access policies, and SecretProviderClass objects
  key_vault_name              = "${local.environment}-kv"
  key_vault_resource_group    = "${local.environment}-kv-rg"
  key_vault_sku               = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  # Kubelet identity is granted "Key Vault Secrets User" RBAC role
  kubelet_identity_object_id = dependency.aks.outputs.kubelet_identity_object_id

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
