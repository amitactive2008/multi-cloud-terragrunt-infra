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

variable "s3_bucket_name" {
  description = "S3 bucket name the Pod Identity role will be granted access to"
  type        = string
}

variable "s3_access_namespace" {
  description = "Kubernetes namespace for the S3-access ServiceAccount"
  type        = string
  default     = "default"
}

variable "s3_access_service_account" {
  description = "Kubernetes ServiceAccount name that will assume the S3-access role"
  type        = string
  default     = "s3-access-sa"
}

variable "tags" {
  description = "Tags to apply to all AWS resources"
  type        = map(string)
  default     = {}
}
