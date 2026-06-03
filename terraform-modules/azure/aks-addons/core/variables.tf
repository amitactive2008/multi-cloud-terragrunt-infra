variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group of the AKS cluster."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from AKS for Workload Identity."
  type        = string
}

variable "metrics_server_version" {
  description = "Helm chart version for metrics-server."
  type        = string
  default     = "3.12.2"
}

variable "tags" {
  description = "Tags to apply to Azure resources."
  type        = map(string)
  default     = {}
}
