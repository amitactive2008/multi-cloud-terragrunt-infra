variable "name" {
  description = "Name of the Virtual Network."
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

variable "address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
}

variable "subnets" {
  description = "Map of subnets to create. Each subnet accepts address_prefixes, service_endpoints, and delegation."
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    private_endpoint_network_policies = optional(string, "Enabled")
    delegation = optional(object({
      name    = string
      service = string
      actions = list(string)
    }))
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
