include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/azure/aks-addons/ingress-nginx"
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
    oidc_issuer_url     = "https://mock.oidc.example.com/"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Ensures core addons are deployed before this module
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
  environment         = local.environment

  # NGINX Ingress Controller Helm chart version
  ingress_nginx_version = "4.11.3"

  # Provisions an Azure Public Load Balancer in front of NGINX
  service_type = "LoadBalancer"

  # Set to true to create a static public IP via azurerm_public_ip
  static_public_ip = false

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
