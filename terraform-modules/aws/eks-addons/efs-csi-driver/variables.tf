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

variable "efs_csi_driver_version" {
  description = "EKS managed addon version for aws-efs-csi-driver"
  type        = string
  default     = "v3.2.0-eksbuild.1"
}

variable "vpc_id" {
  description = "ID of the VPC where EFS mount targets will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC, used for the EFS security group NFS ingress rule"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EFS mount targets (one per AZ)"
  type        = list(string)
}

variable "performance_mode" {
  description = "EFS performance mode: generalPurpose or maxIO"
  type        = string
  default     = "generalPurpose"
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "performance_mode must be 'generalPurpose' or 'maxIO'."
  }
}

variable "throughput_mode" {
  description = "EFS throughput mode: bursting, provisioned, or elastic"
  type        = string
  default     = "elastic"
  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.throughput_mode)
    error_message = "throughput_mode must be 'bursting', 'provisioned', or 'elastic'."
  }
}

variable "transition_to_ia" {
  description = "EFS lifecycle: transition files to IA storage class after this period. Set to empty string to disable."
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "tags" {
  description = "Tags to apply to all AWS resources"
  type        = map(string)
  default     = {}
}
