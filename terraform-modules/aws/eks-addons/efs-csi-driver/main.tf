locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Cluster     = var.cluster_name
  })
}

# ── IAM Role ──────────────────────────────────────────────────────────────────

resource "aws_iam_role" "efs_csi_driver" {
  name = "${var.cluster_name}-efs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = merge(local.common_tags, { Component = "efs-csi-driver" })
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  role       = aws_iam_role.efs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# ── Pod Identity Association ──────────────────────────────────────────────────

resource "aws_eks_pod_identity_association" "efs_csi_driver" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi_driver.arn

  tags = merge(local.common_tags, { Component = "efs-csi-driver" })
}

# ── EKS Managed Addon ─────────────────────────────────────────────────────────

resource "aws_eks_addon" "efs_csi_driver" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-efs-csi-driver"
  addon_version               = var.efs_csi_driver_version
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.common_tags, { Addon = "efs-csi-driver" })

  depends_on = [
    aws_iam_role_policy_attachment.efs_csi_driver,
    aws_eks_pod_identity_association.efs_csi_driver,
  ]
}

# ── EFS Security Group ────────────────────────────────────────────────────────

resource "aws_security_group" "efs" {
  name        = "${var.cluster_name}-efs-sg"
  description = "Allow NFS inbound from VPC to EFS mount targets"
  vpc_id      = var.vpc_id

  ingress {
    description = "NFS from VPC CIDR"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-efs-sg" })
}

# ── EFS File System ───────────────────────────────────────────────────────────

resource "aws_efs_file_system" "this" {
  creation_token   = "${var.cluster_name}-efs"
  encrypted        = true
  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode

  dynamic "lifecycle_policy" {
    for_each = var.transition_to_ia != "" ? [var.transition_to_ia] : []
    content {
      transition_to_ia = lifecycle_policy.value
    }
  }

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-efs" })
}

# ── EFS Mount Targets (one per private subnet / AZ) ──────────────────────────

resource "aws_efs_mount_target" "this" {
  for_each = toset(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

# ── EFS Access Point ──────────────────────────────────────────────────────────

resource "aws_efs_access_point" "root" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-efs-root-ap" })
}

# ── EFS StorageClass ──────────────────────────────────────────────────────────

resource "kubernetes_storage_class" "efs" {
  metadata {
    name = "efs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "efs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = false

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.this.id
    directoryPerms   = "755"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    basePath         = "/dynamic"
  }

  depends_on = [
    aws_eks_addon.efs_csi_driver,
    aws_efs_mount_target.this,
  ]
}
