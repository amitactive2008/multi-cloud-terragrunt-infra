variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version."
  type        = string
}

variable "sku_tier" {
  description = "SKU tier: Free, Standard, or Premium."
  type        = string
  default     = "Free"
}

variable "vnet_id" {
  description = "ID of the Virtual Network."
  type        = string
}

variable "aks_subnet_id" {
  description = "ID of the subnet for the AKS node pools."
  type        = string
}

variable "system_node_pool" {
  description = "Configuration for the default system node pool."
  type = object({
    name                = string
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
    os_disk_size_gb     = number
    node_labels         = optional(map(string), {})
  })
}

variable "user_node_pools" {
  description = "Map of additional user node pool configurations."
  type = map(object({
    name                = string
    vm_size             = string
    node_count          = number
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
    os_disk_size_gb     = number
    node_labels         = optional(map(string), {})
  }))
  default = {}
}

variable "network_plugin" {
  description = "Network plugin: azure or kubenet."
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy: azure, calico, or cilium."
  type        = string
  default     = "azure"
}

variable "load_balancer_sku" {
  description = "Load balancer SKU: basic or standard."
  type        = string
  default     = "standard"
}

variable "oidc_issuer_enabled" {
  description = "Enable OIDC issuer for Workload Identity."
  type        = bool
  default     = true
}

variable "workload_identity_enabled" {
  description = "Enable Azure Workload Identity."
  type        = bool
  default     = true
}

variable "key_vault_secrets_provider_enabled" {
  description = "Enable the Key Vault Secrets Provider addon."
  type        = bool
  default     = true
}

variable "api_server_authorized_ip_ranges" {
  description = "List of IP ranges authorized to access the API server. Empty = unrestricted."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
