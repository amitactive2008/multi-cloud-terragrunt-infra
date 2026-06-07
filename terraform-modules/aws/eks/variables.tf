variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for node groups (must be in at least 2 AZs)"
  type        = list(string)
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size_gb   = optional(number, 50)
    capacity_type  = optional(string, "ON_DEMAND") # ON_DEMAND or SPOT
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {
    default = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      disk_size_gb   = 50
      capacity_type  = "ON_DEMAND"
    }
  }
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to the cluster API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the cluster API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to access the public cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "List of EKS control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_admin_arns" {
  description = "Additional IAM user/role ARNs to grant AmazonEKSClusterAdminPolicy via EKS access entries. Individual users/roles added alongside any group-based role."
  type        = list(string)
  default     = []
}

variable "devops_admin_groups" {
  description = "List of IAM group names whose members need EKS cluster-admin access. A shared IAM role is created per group; group members assume that role to access the cluster. Adding/removing users from the group takes effect immediately — no Terraform re-apply required."
  type        = list(string)
  default     = []
}

variable "account_id" {
  description = "AWS account ID — used to build IAM ARNs for group-based access roles."
  type        = string
}

variable "authentication_mode" {
  description = "Authentication mode for the EKS cluster. Use API_AND_CONFIG_MAP to support both access entries and aws-auth configmap."
  type        = string
  default     = "API_AND_CONFIG_MAP"
}
