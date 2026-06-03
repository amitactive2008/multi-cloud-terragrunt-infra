output "cluster_autoscaler_status" {
  description = "Deployment status of cluster-autoscaler."
  value       = helm_release.cluster_autoscaler.status
}
