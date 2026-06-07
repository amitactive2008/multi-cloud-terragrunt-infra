output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster control plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID of the EKS node groups"
  value       = aws_security_group.node.id
}

output "cluster_iam_role_arn" {
  description = "ARN of the IAM role used by the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "ARN of the IAM role used by the EKS node groups"
  value       = aws_iam_role.node.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider (used for IRSA)"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = aws_iam_openid_connect_provider.this.url
}

output "devops_eks_admin_role_arns" {
  description = "Map of group-name => IAM role ARN created for EKS cluster-admin access. Group members assume these roles to access the cluster."
  value       = { for g, r in aws_iam_role.devops_eks_admin : g => r.arn }
}

output "node_groups" {
  description = "Map of node group names to their status"
  value = {
    for k, ng in aws_eks_node_group.this : k => {
      arn    = ng.arn
      status = ng.status
    }
  }
}
