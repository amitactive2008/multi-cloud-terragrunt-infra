variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the cluster resides"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "external_dns_version" {
  description = "Helm chart version for external-dns"
  type        = string
  default     = "1.15.0"
}

variable "external_dns_namespace" {
  description = "Kubernetes namespace for external-dns"
  type        = string
  default     = "external-dns"
}

variable "create_namespace" {
  description = "Create the namespace if it does not exist"
  type        = bool
  default     = true
}

variable "route53_zone_ids" {
  description = "List of Route53 zone IDs to manage (e.g., [\"Z00208349B1KPAQN1J8J\"])"
  type        = list(string)
  default     = []
}

variable "route53_domain_filters" {
  description = "Limit external-dns to specific domain names (e.g., [\"linuxworms.in\"])"
  type        = list(string)
  default     = []
}

variable "policy" {
  description = "Policy for managing records (sync, upsert-only)"
  type        = string
  default     = "sync"
  validation {
    condition     = contains(["sync", "upsert-only"], var.policy)
    error_message = "Policy must be either 'sync' or 'upsert-only'."
  }
}

variable "txt_owner_id" {
  description = "TXT record owner ID for identifying managed records"
  type        = string
  default     = ""
}

variable "replicas" {
  description = "Number of external-dns replicas to deploy"
  type        = number
  default     = 1
}

variable "log_level" {
  description = "Log level for external-dns (debug, info, warning, error)"
  type        = string
  default     = "info"
}

variable "interval" {
  description = "Reconciliation interval (e.g., 1m, 5m)"
  type        = string
  default     = "1m"
}

variable "trigger_loop_on_event" {
  description = "Trigger DNS update on resource changes"
  type        = bool
  default     = true
}

variable "sources" {
  description = "List of K8s sources to extract DNS records from (service, ingress, etc.)"
  type        = list(string)
  default     = ["ingress", "service"]
}

variable "helm_set_values" {
  description = "Additional Helm values as key-value pairs"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all AWS resources"
  type        = map(string)
  default     = {}
}
