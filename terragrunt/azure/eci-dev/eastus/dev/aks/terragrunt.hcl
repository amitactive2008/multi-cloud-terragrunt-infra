include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../terraform-modules/azure/aks"
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

dependency "vnet" {
  config_path = "../vnet"
  mock_outputs = {
    vnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
    aks_subnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/aks"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name        = "${local.environment}-aks"
  resource_group_name = "${local.environment}-aks-rg"
  location            = local.azure_region
  kubernetes_version  = "1.32"
  sku_tier            = "Free"

  vnet_id       = dependency.vnet.outputs.vnet_id
  aks_subnet_id = dependency.vnet.outputs.aks_subnet_id

  # System node pool
  system_node_pool = {
    name                = "system"
    vm_size             = "Standard_D2s_v3"
    node_count          = 2
    min_count           = 1
    max_count           = 5
    enable_auto_scaling = true
    os_disk_size_gb     = 50
    node_labels = {
      role = "system"
    }
  }

  # User node pool for workloads
  user_node_pools = {
    general = {
      name                = "general"
      vm_size             = "Standard_D2s_v3"
      node_count          = 2
      min_count           = 1
      max_count           = 10
      enable_auto_scaling = true
      os_disk_size_gb     = 50
      node_labels = {
        role = "general"
      }
    }
  }

  network_plugin    = "azure"
  network_policy    = "azure"
  load_balancer_sku = "standard"

  # Enable OIDC issuer + Workload Identity (replaces Pod Identity)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Enable Key Vault CSI driver
  key_vault_secrets_provider_enabled = true

  api_server_authorized_ip_ranges = []

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
