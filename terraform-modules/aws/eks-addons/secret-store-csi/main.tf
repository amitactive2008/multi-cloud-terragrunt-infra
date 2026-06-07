locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Cluster     = var.cluster_name
  })
}

# ── Secrets Store CSI Driver ──────────────────────────────────────────────────

resource "helm_release" "secrets_store_csi_driver" {
  name             = "secrets-store-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart            = "secrets-store-csi-driver"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }
  set {
    name  = "enableSecretRotation"
    value = "true"
  }
  # Required for Pod Identity: CSIDriver must declare tokenRequests audiences
  set {
    name  = "tokenRequests[0].audience"
    value = "sts.amazonaws.com"
  }
  set {
    name  = "tokenRequests[1].audience"
    value = "pods.eks.amazonaws.com"
  }
}

# ── AWS Secrets Manager provider for CSI driver ───────────────────────────────

resource "helm_release" "aws_secrets_provider" {
  name             = "secrets-provider-aws"
  repository       = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart            = "secrets-store-csi-driver-provider-aws"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  # The provider chart v3.x bundles the CSI driver as a subchart — disable it
  # since we already install secrets-store-csi-driver separately above.
  set {
    name  = "secrets-store-csi-driver.install"
    value = "false"
  }

  depends_on = [helm_release.secrets_store_csi_driver]
}

# ── IAM Role ──────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "rds_secret_read" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [var.rds_secret_arn]
  }
}

resource "aws_iam_role" "rds_secret_reader" {
  name               = "${var.cluster_name}-rds-secret-reader"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = merge(local.common_tags, { Component = "secret-store-csi" })
}

resource "aws_iam_role_policy" "rds_secret_read" {
  name   = "rds-secret-read"
  role   = aws_iam_role.rds_secret_reader.name
  policy = data.aws_iam_policy_document.rds_secret_read.json
}

# ── Pod Identity Association ──────────────────────────────────────────────────

resource "aws_eks_pod_identity_association" "rds" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.rds_secret_reader.arn

  tags = merge(local.common_tags, { Component = "secret-store-csi" })
}

# ── Kubernetes ServiceAccount ─────────────────────────────────────────────────

resource "kubernetes_service_account_v1" "rds" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
  }
}

# ── SecretProviderClass via kubectl ───────────────────────────────────────────
# kubernetes_manifest validates CRDs at plan time (before Helm installs them),
# so we use a null_resource + local-exec kubectl apply instead.

resource "null_resource" "secret_provider_class" {
  triggers = {
    cluster_name               = var.cluster_name
    namespace                  = var.namespace
    secret_provider_class_name = var.secret_provider_class_name
    rds_secret_arn             = var.rds_secret_arn
    aws_region                 = var.aws_region
    account_id                 = var.account_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOF
      CREDS=$(aws sts assume-role \
        --role-arn arn:aws:iam::${var.account_id}:role/terraform \
        --role-session-name kubectl-session \
        --profile ${var.aws_profile} \
        --output json)
      export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['Credentials']['AccessKeyId'])")
      export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['Credentials']['SecretAccessKey'])")
      export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['Credentials']['SessionToken'])")
      unset AWS_PROFILE
      aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
      kubectl apply --validate=false -f - <<YAML
      apiVersion: secrets-store.csi.x-k8s.io/v1
      kind: SecretProviderClass
      metadata:
        name: ${var.secret_provider_class_name}
        namespace: ${var.namespace}
      spec:
        provider: aws
        parameters:
          usePodIdentity: "true"
          objects: |
            - objectName: "${var.rds_secret_arn}"
              objectType: "secretsmanager"
              jmesPath:
                - path: "username"
                  objectAlias: "username"
                - path: "password"
                  objectAlias: "password"
                - path: "host"
                  objectAlias: "host"
                - path: "port"
                  objectAlias: "port"
                - path: "dbname"
                  objectAlias: "dbname"
        secretObjects:
          - secretName: rds-credentials
            type: Opaque
            data:
              - objectName: username
                key: username
              - objectName: password
                key: password
              - objectName: host
                key: host
              - objectName: port
                key: port
              - objectName: dbname
                key: dbname
      YAML
    EOF
    environment = {
      AWS_PROFILE = "jenkins"
      AWS_REGION  = var.aws_region
    }
  }

  depends_on = [
    helm_release.secrets_store_csi_driver,
    helm_release.aws_secrets_provider,
    aws_eks_pod_identity_association.rds,
  ]
}
