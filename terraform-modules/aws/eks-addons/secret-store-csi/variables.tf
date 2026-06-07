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

variable "aws_profile" {
  description = "AWS CLI profile to use for kubectl update-kubeconfig"
  type        = string
  default     = "jenkins"
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

variable "namespace" {
  description = "Kubernetes namespace for the ServiceAccount and SecretProviderClass"
  type        = string
  default     = "default"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name that will mount RDS credentials"
  type        = string
  default     = "rds-sa"
}

variable "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  type        = string
}

variable "secret_provider_class_name" {
  description = "Name of the SecretProviderClass resource"
  type        = string
  default     = "rds-credentials"
}

variable "tags" {
  description = "Tags to apply to all AWS resources"
  type        = map(string)
  default     = {}
}
