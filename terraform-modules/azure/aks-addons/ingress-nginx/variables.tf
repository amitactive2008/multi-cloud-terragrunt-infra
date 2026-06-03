variable "cluster_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "subscription_id" { type = string }
variable "environment" { type = string }
variable "oidc_issuer_url" { type = string }
variable "ingress_nginx_version" { type = string; default = "4.11.3" }
variable "service_type" { type = string; default = "LoadBalancer" }
variable "static_public_ip" { type = bool; default = false }
variable "tags" { type = map(string); default = {} }
