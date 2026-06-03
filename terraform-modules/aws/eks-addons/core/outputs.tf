output "pod_identity_agent_addon_arn" {
  description = "ARN of the EKS Pod Identity Agent addon"
  value       = aws_eks_addon.pod_identity_agent.arn
}

output "coredns_addon_arn" {
  description = "ARN of the CoreDNS EKS addon"
  value       = aws_eks_addon.coredns.arn
}

output "kube_proxy_addon_arn" {
  description = "ARN of the kube-proxy EKS addon"
  value       = aws_eks_addon.kube_proxy.arn
}

output "vpc_cni_addon_arn" {
  description = "ARN of the vpc-cni EKS addon"
  value       = aws_eks_addon.vpc_cni.arn
}

output "vpc_cni_role_arn" {
  description = "ARN of the IAM role for vpc-cni (Pod Identity)"
  value       = aws_iam_role.vpc_cni.arn
}
