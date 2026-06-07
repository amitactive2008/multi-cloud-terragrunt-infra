locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Cluster     = var.cluster_name
  })
}

# ── IAM Role ──────────────────────────────────────────────────────────────────

resource "aws_iam_role" "lb_controller" {
  name = "${var.cluster_name}-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = merge(local.common_tags, { Component = "lb-controller" })
}

resource "aws_iam_policy" "lb_controller" {
  name        = "${var.cluster_name}-lb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/lb-controller-policy.json")

  tags = merge(local.common_tags, { Component = "lb-controller" })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# ── Pod Identity Association ──────────────────────────────────────────────────

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn

  tags = merge(local.common_tags, { Component = "lb-controller" })
}

# ── Helm Release ──────────────────────────────────────────────────────────────

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [aws_eks_pod_identity_association.lb_controller]
}

# ── IngressClass ──────────────────────────────────────────────────────────────

resource "kubernetes_ingress_class_v1" "alb" {
  metadata {
    name = "alb"
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    controller = "ingress.k8s.aws/alb"
  }

  depends_on = [helm_release.lb_controller]
}
