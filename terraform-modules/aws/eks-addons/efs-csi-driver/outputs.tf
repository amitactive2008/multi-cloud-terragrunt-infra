output "efs_csi_role_arn" {
  description = "ARN of the IAM role for EFS CSI driver"
  value       = aws_iam_role.efs_csi_driver.arn
}

output "efs_csi_addon_arn" {
  description = "ARN of the aws-efs-csi-driver EKS addon"
  value       = aws_eks_addon.efs_csi_driver.arn
}

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.this.id
}

output "efs_file_system_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.this.arn
}

output "efs_file_system_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.this.dns_name
}

output "efs_access_point_id" {
  description = "ID of the default EFS access point"
  value       = aws_efs_access_point.root.id
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs.id
}

output "efs_storage_class" {
  description = "Name of the EFS StorageClass created by this module"
  value       = kubernetes_storage_class.efs.metadata[0].name
}
