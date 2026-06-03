# terraform-modules/azure/vnet

Creates an Azure Virtual Network with configurable subnets. Supports subnet delegation (for MySQL Flexible Server), service endpoints, and private endpoint policies.

## Resources Created

| Resource | Description |
|----------|-------------|
| `azurerm_resource_group` | Resource group for the VNet |
| `azurerm_virtual_network` | Virtual Network |
| `azurerm_subnet` (×N) | One per entry in `var.subnets` |

## Usage

```hcl
module "vnet" {
  source              = "../../terraform-modules/azure/vnet"
  name                = "dev-vnet"
  resource_group_name = "dev-network-rg"
  location            = "eastus"
  address_space       = ["10.0.0.0/8"]

  subnets = {
    aks = {
      address_prefixes  = ["10.0.0.0/16"]
      service_endpoints = ["Microsoft.ContainerRegistry", "Microsoft.KeyVault"]
    }
    database = {
      address_prefixes = ["10.1.0.0/24"]
      delegation = {
        name    = "mysql-flexible"
        service = "Microsoft.DBforMySQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    privatelink = {
      address_prefixes                  = ["10.1.1.0/24"]
      private_endpoint_network_policies = "Disabled"
    }
  }

  tags = { Environment = "dev", ManagedBy = "terraform" }
}
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `name` | `string` | yes | VNet name |
| `resource_group_name` | `string` | yes | Resource group name (created by this module) |
| `location` | `string` | yes | Azure region |
| `address_space` | `list(string)` | yes | CIDR blocks for the VNet |
| `subnets` | `map(object)` | no | Map of subnets to create |
| `tags` | `map(string)` | no | Tags applied to all resources |

## Outputs

| Name | Description |
|------|-------------|
| `vnet_id` | VNet resource ID |
| `vnet_name` | VNet name |
| `resource_group_name` | Resource group name |
| `aks_subnet_id` | ID of the `aks` subnet |
| `database_subnet_id` | ID of the `database` subnet |
| `privatelink_subnet_id` | ID of the `privatelink` subnet |
| `subnet_ids` | Map of all subnet IDs keyed by name |
