output "s3_access_role_arn" {
  description = "ARN of the IAM role for S3 access via Pod Identity"
  value       = aws_iam_role.s3_access.arn
}

output "s3_access_service_account" {
  description = "Kubernetes ServiceAccount name for S3 access"
  value       = kubernetes_service_account_v1.s3_access.metadata[0].name
}
