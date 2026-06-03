output "iam_role_arn" {
  description = "ARN of the IAM role granted access to the RDS secret"
  value       = aws_iam_role.rds_secret_reader.arn
}

output "pod_identity_association_arn" {
  description = "ARN of the EKS Pod Identity association for RDS"
  value       = aws_eks_pod_identity_association.rds.association_arn
}

output "service_account_name" {
  description = "Kubernetes ServiceAccount name that mounts RDS credentials"
  value       = kubernetes_service_account_v1.rds.metadata[0].name
}

output "secret_provider_class_name" {
  description = "Name of the SecretProviderClass (reference this in pod volumes)"
  value       = var.secret_provider_class_name
}

output "k8s_secret_name" {
  description = "Kubernetes Secret name synced from Secrets Manager"
  value       = "rds-credentials"
}
