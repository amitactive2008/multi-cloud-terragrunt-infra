output "ebs_csi_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "ebs_csi_addon_arn" {
  description = "ARN of the aws-ebs-csi-driver EKS addon"
  value       = aws_eks_addon.ebs_csi_driver.arn
}

output "ebs_gp3_storage_class" {
  description = "Name of the gp3 StorageClass created by the EBS CSI driver"
  value       = kubernetes_storage_class.ebs_gp3.metadata[0].name
}
