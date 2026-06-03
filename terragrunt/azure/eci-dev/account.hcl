locals {
  cloud                 = "azure"
  account_name          = "eci-dev"
  subscription_id       = "00000000-0000-0000-0000-000000000001"  # replace with real subscription ID
  tenant_id             = "00000000-0000-0000-0000-000000000000"  # replace with real tenant ID
  state_resource_group  = "terraform-state-rg"
  state_storage_account = "tfstateecidevstorage"                  # 3-24 chars, lowercase alphanumeric only
}
