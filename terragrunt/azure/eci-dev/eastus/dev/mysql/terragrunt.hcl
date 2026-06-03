include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../terraform-modules/azure/mysql"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  azure_region = local.region_vars.locals.azure_region
  environment  = local.env_vars.locals.environment
}

dependency "vnet" {
  config_path = "../vnet"
  mock_outputs = {
    vnet_id              = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
    database_subnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/database"
    privatelink_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/privatelink"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "aks" {
  config_path = "../aks"
  mock_outputs = {
    node_resource_group = "mock-node-rg"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  name                = "${local.environment}-mysql"
  resource_group_name = "${local.environment}-data-rg"
  location            = local.azure_region

  mysql_version  = "8.0.21"
  sku_name       = "B_Standard_B1ms"
  storage_size_gb = 20
  iops           = 396

  administrator_login    = "mysqladmin"
  # Password is generated and stored in Key Vault — do not set here

  database_subnet_id    = dependency.vnet.outputs.database_subnet_id
  private_dns_zone_vnet_id = dependency.vnet.outputs.vnet_id

  databases = ["appdb"]

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # Store credentials in Azure Key Vault
  key_vault_id = ""  # set after key vault is provisioned

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
