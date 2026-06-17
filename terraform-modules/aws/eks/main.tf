locals {
  common_tags = merge(
    { Name = var.cluster_name, ManagedBy = "terraform" },
    var.tags
  )

  # SSM paths for the latest EKS-optimised AMI release version per AMI type
  ami_ssm_paths = {
    "AL2_x86_64"             = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2/recommended/release_version"
    "AL2_x86_64_GPU"         = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2-gpu/recommended/release_version"
    "AL2023_x86_64_STANDARD" = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2023/x86_64/standard/recommended/release_version"
    "AL2023_ARM_64_STANDARD" = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2023/arm64/standard/recommended/release_version"
  }

  # Merge explicit ARNs + one role ARN per devops group
  all_admin_arns = toset(concat(
    var.cluster_admin_arns,
    [for g in var.devops_admin_groups : "arn:aws:iam::${var.account_id}:role/${var.cluster_name}-${g}-group-EKSAdminFullAccessRole"]
  ))
}

# Look up the latest AMI release version for each node group's AMI type
data "aws_ssm_parameter" "node_ami_release" {
  for_each = { for k, v in var.node_groups : k => v.ami_type }
  name     = local.ami_ssm_paths[each.value]
}

# ─── IAM Role: EKS Cluster ──────────────────────────────────────────────────
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ─── IAM Role: EKS Node Group ───────────────────────────────────────────────
data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# ─── Security Group: Cluster ────────────────────────────────────────────────
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-cluster-sg" })
}

# Allow nodes to communicate with the cluster API
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description              = "Allow nodes to communicate with the cluster API"
}

# ─── Security Group: Nodes ──────────────────────────────────────────────────
resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS node group security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow node-to-node communication"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-node-sg" })
}

resource "aws_security_group_rule" "node_ingress_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow cluster control plane to reach nodes"
}

# ─── EKS Cluster ────────────────────────────────────────────────────────────
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]

  tags = local.common_tags
}

# ─── OIDC Provider (for IRSA) ───────────────────────────────────────────────
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags            = local.common_tags
}

# ─── EKS Node Groups (private subnets) ──────────────────────────────────────
resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types  = each.value.instance_types
  capacity_type   = each.value.capacity_type
  ami_type        = each.value.ami_type
  disk_size       = each.value.disk_size_gb
  release_version = data.aws_ssm_parameter.node_ami_release[each.key].value

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable = 1
  }

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  labels = each.value.labels

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = merge(local.common_tags, { NodeGroup = each.key })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# ─── EKS Access Entries (console / kubectl access for IAM users & roles) ─────
#
# IAM groups cannot be granted EKS access directly. Instead, a dedicated IAM
# role is created for each group listed in var.devops_admin_groups. Group
# members assume the role to gain cluster-admin access — adding/removing a user
# from the group takes effect immediately without any Terraform re-apply.
# ─────────────────────────────────────────────────────────────────────────────

# Ensure IAM groups exist for every configured admin group name
resource "aws_iam_group" "devops_eks_admin" {
  for_each = toset(var.devops_admin_groups)
  name     = each.value
}

# One assumable role per devops admin group
resource "aws_iam_role" "devops_eks_admin" {
  for_each = toset(var.devops_admin_groups)

  name        = "${var.cluster_name}-${each.value}-group-EKSAdminFullAccessRole"
  description = "Assumed by members of the ${each.value} IAM group for EKS cluster-admin access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
      Condition = {
        StringLike = {
          "aws:PrincipalArn" = "arn:aws:iam::${var.account_id}:user/*"
        }
      }
    }]
  })

  tags = merge(local.common_tags, { Group = each.value })
}

# IAM policy required for EKS Console and API access after role assumption
resource "aws_iam_role_policy" "devops_eks_admin_console" {
  for_each = toset(var.devops_admin_groups)

  name = "${var.cluster_name}-${each.value}-group-EKSAdminFullAccessPolicy"
  role = aws_iam_role.devops_eks_admin[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "VisualEditor0"
      Effect   = "Allow"
      Action   = "eks:*"
      Resource = "*"
    }]
  })
}

# Inline policy on each group that allows its members to assume the role
resource "aws_iam_group_policy" "devops_assume_eks_admin" {
  for_each = toset(var.devops_admin_groups)

  name  = "assume-${each.value}-eks-admin"
  group = aws_iam_group.devops_eks_admin[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.devops_eks_admin[each.key].arn
    }]
  })
}

# Access entry + cluster-admin policy for every ARN (explicit + group roles)
resource "aws_eks_access_entry" "admins" {
  for_each = local.all_admin_arns

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = local.common_tags
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = local.all_admin_arns

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}
