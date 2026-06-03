variable "cluster_name" { type = string }
variable "resource_group_name" { type = string }
variable "node_resource_group" { type = string }
variable "location" { type = string }
variable "subscription_id" { type = string }
variable "environment" { type = string }
variable "oidc_issuer_url" { type = string }
variable "cluster_autoscaler_version" { type = string; default = "9.43.2" }
variable "service_account_name" { type = string; default = "cluster-autoscaler" }
variable "service_account_namespace" { type = string; default = "kube-system" }
variable "tags" { type = map(string); default = {} }
