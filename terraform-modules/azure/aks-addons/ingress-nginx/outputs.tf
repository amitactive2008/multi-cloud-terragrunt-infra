output "ingress_nginx_status" {
  description = "Deployment status of ingress-nginx."
  value       = helm_release.ingress_nginx.status
}
