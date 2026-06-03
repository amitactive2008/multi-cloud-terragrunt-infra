locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Cluster     = var.cluster_name
  })
}

# ── IAM Role ──────────────────────────────────────────────────────────────────

resource "aws_iam_role" "s3_access" {
  name = "${var.cluster_name}-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "s3_access" {
  name        = "${var.cluster_name}-s3-access-policy"
  description = "IAM policy for S3 access via Pod Identity"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSpecificBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion",
          "s3:ListBucketMultipartUploads",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*",
        ]
      },
      {
        Sid      = "AllowListAllBuckets"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = ["*"]
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.s3_access.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# ── Pod Identity Association ──────────────────────────────────────────────────

resource "aws_eks_pod_identity_association" "s3_access" {
  cluster_name    = var.cluster_name
  namespace       = var.s3_access_namespace
  service_account = var.s3_access_service_account
  role_arn        = aws_iam_role.s3_access.arn

  tags = merge(local.common_tags, { Component = "s3-access" })
}

# ── Kubernetes ServiceAccount ─────────────────────────────────────────────────

resource "kubernetes_service_account_v1" "s3_access" {
  metadata {
    name      = var.s3_access_service_account
    namespace = var.s3_access_namespace

    labels = {
      app       = "s3-access"
      component = "pod-identity"
    }
  }

  depends_on = [aws_eks_pod_identity_association.s3_access]
}
