locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Cluster     = var.cluster_name
  })
}

# ── IAM Role ──────────────────────────────────────────────────────────────────

resource "aws_iam_role" "external_dns" {
  name = "${var.cluster_name}-external-dns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = merge(local.common_tags, { Component = "external-dns" })
}

resource "aws_iam_policy" "external_dns" {
  name        = "${var.cluster_name}-external-dns-policy"
  description = "IAM policy for External DNS to manage Route53 records"
  policy      = file("${path.module}/external-dns-policy.json")

  tags = merge(local.common_tags, { Component = "external-dns" })
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

# ── Pod Identity Association ──────────────────────────────────────────────────

resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = var.cluster_name
  namespace       = var.external_dns_namespace
  service_account = "external-dns"
  role_arn        = aws_iam_role.external_dns.arn

  tags = merge(local.common_tags, { Component = "external-dns" })
}

# ── Kubernetes Namespace ───────────────────────────────────────────────────────

resource "kubernetes_namespace" "external_dns" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.external_dns_namespace
    labels = {
      "app.kubernetes.io/name" = "external-dns"
    }
  }

  depends_on = [aws_eks_pod_identity_association.external_dns]
}

# ── Helm Release ───────────────────────────────────────────────────────────────

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_version
  namespace  = var.external_dns_namespace

  # Create namespace if not already present
  create_namespace = !var.create_namespace

  # Basic configuration
  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  # AWS region
  set {
    name  = "aws.region"
    value = var.aws_region
  }

  # Policy settings
  set {
    name  = "policy"
    value = var.policy
  }

  # TXT owner ID (if provided)
  dynamic "set" {
    for_each = var.txt_owner_id != "" ? [1] : []
    content {
      name  = "txtOwnerId"
      value = var.txt_owner_id
    }
  }

  # Route53 zone ID filtering (as list)
  set_list {
    name  = "aws.zoneIdFilters"
    value = var.route53_zone_ids
  }

  # Route53 domain filtering (as list)
  set_list {
    name  = "domainFilters"
    value = var.route53_domain_filters
  }

  # Replicas
  set {
    name  = "replicas"
    value = var.replicas
  }

  # Log level
  set {
    name  = "logLevel"
    value = var.log_level
  }

  # Reconciliation interval
  set {
    name  = "interval"
    value = var.interval
  }

  # Trigger on resource changes
  set {
    name  = "triggerLoopOnEvent"
    value = var.trigger_loop_on_event
  }

  # DNS sources (as list)
  set_list {
    name  = "sources"
    value = var.sources
  }

  # Dynamic additional Helm values
  dynamic "set" {
    for_each = var.helm_set_values
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [
    aws_eks_pod_identity_association.external_dns,
    kubernetes_namespace.external_dns,
  ]
}
