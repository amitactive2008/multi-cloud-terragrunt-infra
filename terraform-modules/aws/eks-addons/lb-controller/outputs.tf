output "lb_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

output "ingress_class_name" {
  description = "Name of the ALB IngressClass"
  value       = kubernetes_ingress_class_v1.alb.metadata[0].name
}
