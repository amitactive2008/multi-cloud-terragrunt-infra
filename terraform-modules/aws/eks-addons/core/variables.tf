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
  description = "AWS account ID (used to construct role ARN for kubectl auth)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "coredns_version" {
  description = "EKS managed addon version for CoreDNS"
  type        = string
  default     = "v1.14.3-eksbuild.2"
}

variable "kube_proxy_version" {
  description = "EKS managed addon version for kube-proxy"
  type        = string
  default     = "v1.35.3-eksbuild.11"
}

variable "vpc_cni_version" {
  description = "EKS managed addon version for vpc-cni"
  type        = string
  default     = "v1.22.1-eksbuild.2"
}

variable "metrics_server_version" {
  description = "Helm chart version for metrics-server"
  type        = string
  default     = "3.12.2"
}

variable "tags" {
  description = "Tags to apply to all AWS resources"
  type        = map(string)
  default     = {}
}
