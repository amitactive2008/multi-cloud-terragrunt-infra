include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../terraform-modules/azure/vnet"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  azure_region = local.region_vars.locals.azure_region
  environment  = local.env_vars.locals.environment
}

inputs = {
  name                = "${local.environment}-vnet"
  resource_group_name = "${local.environment}-network-rg"
  location            = local.azure_region
  address_space       = ["10.0.0.0/8"]

  subnets = {
    aks = {
      address_prefixes  = ["10.0.0.0/16"]
      # Required for AKS with Azure CNI
      service_endpoints = ["Microsoft.ContainerRegistry", "Microsoft.KeyVault"]
    }
    database = {
      address_prefixes  = ["10.1.0.0/24"]
      service_endpoints = ["Microsoft.Sql"]
      delegation = {
        name    = "mysql-flexible"
        service = "Microsoft.DBforMySQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    privatelink = {
      address_prefixes                              = ["10.1.1.0/24"]
      private_endpoint_network_policies             = "Disabled"
    }
  }

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
