output "external_dns_role_arn" {
  description = "ARN of the IAM role for External DNS"
  value       = aws_iam_role.external_dns.arn
}

output "external_dns_role_name" {
  description = "Name of the IAM role for External DNS"
  value       = aws_iam_role.external_dns.name
}

output "helm_release_name" {
  description = "Helm release name for external-dns"
  value       = helm_release.external_dns.name
}

output "helm_release_status" {
  description = "Helm release status"
  value       = helm_release.external_dns.status
}

output "helm_release_version" {
  description = "Helm release version"
  value       = helm_release.external_dns.version
}

output "namespace" {
  description = "Kubernetes namespace where external-dns is deployed"
  value       = var.external_dns_namespace
}

output "pod_identity_association_id" {
  description = "Pod Identity Association ID"
  value       = aws_eks_pod_identity_association.external_dns.id
}
