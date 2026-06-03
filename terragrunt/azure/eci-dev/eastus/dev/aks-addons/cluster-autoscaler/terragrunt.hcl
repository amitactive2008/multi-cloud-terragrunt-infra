include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/azure/aks-addons/cluster-autoscaler"
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
    node_resource_group = "dev-aks-node-rg"
    kubelet_identity_client_id    = "00000000-0000-0000-0000-000000000000"
    kubelet_identity_object_id    = "00000000-0000-0000-0000-000000000000"
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
  node_resource_group = dependency.aks.outputs.node_resource_group
  location            = local.azure_region
  subscription_id     = local.subscription_id
  environment         = local.environment
  oidc_issuer_url     = dependency.aks.outputs.oidc_issuer_url

  # AKS already has node autoscaling enabled — this deploys the standalone
  # Helm-based cluster-autoscaler for additional control (optional)
  cluster_autoscaler_version = "9.43.2"

  # Service account for cluster-autoscaler pod (used with Workload Identity)
  service_account_name      = "cluster-autoscaler"
  service_account_namespace = "kube-system"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
