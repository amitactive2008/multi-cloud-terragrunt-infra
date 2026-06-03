output "metrics_server_status" {
  description = "Deployment status of metrics-server."
  value       = helm_release.metrics_server.status
}
