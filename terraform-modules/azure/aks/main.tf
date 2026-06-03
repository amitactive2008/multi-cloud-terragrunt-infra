terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  dns_prefix = var.cluster_name

  default_node_pool {
    name                = var.system_node_pool.name
    vm_size             = var.system_node_pool.vm_size
    node_count          = var.system_node_pool.node_count
    min_count           = var.system_node_pool.enable_auto_scaling ? var.system_node_pool.min_count : null
    max_count           = var.system_node_pool.enable_auto_scaling ? var.system_node_pool.max_count : null
    auto_scaling_enabled = var.system_node_pool.enable_auto_scaling
    os_disk_size_gb     = var.system_node_pool.os_disk_size_gb
    vnet_subnet_id      = var.aks_subnet_id
    node_labels         = var.system_node_pool.node_labels
    only_critical_addons_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    load_balancer_sku = var.load_balancer_sku
  }

  oidc_issuer_enabled       = var.oidc_issuer_enabled
  workload_identity_enabled = var.workload_identity_enabled

  dynamic "key_vault_secrets_provider" {
    for_each = var.key_vault_secrets_provider_enabled ? [1] : []
    content {
      secret_rotation_enabled = true
    }
  }

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = var.user_node_pools

  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  name                  = each.value.name
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  min_count             = each.value.enable_auto_scaling ? each.value.min_count : null
  max_count             = each.value.enable_auto_scaling ? each.value.max_count : null
  auto_scaling_enabled  = each.value.enable_auto_scaling
  os_disk_size_gb       = each.value.os_disk_size_gb
  vnet_subnet_id        = var.aks_subnet_id
  node_labels           = each.value.node_labels
  tags                  = var.tags
}
