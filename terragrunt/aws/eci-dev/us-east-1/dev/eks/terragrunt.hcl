include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../terraform-modules/aws/eks"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_id   = local.account_vars.locals.aws_account_id
  environment  = local.env_vars.locals.environment
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name       = "dev-eks"
  kubernetes_version = "1.36"
  account_id         = local.account_id

  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      disk_size_gb   = 50
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD"
      labels = {
        role = "general"
      }
    }
  }

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  # IAM groups whose members get EKS cluster-admin access via an assumable role.
  # Adding/removing users from the group takes effect immediately — no re-apply needed.
  devops_admin_groups = ["devops"]

  # Individual users/service accounts that also need cluster-admin access.
  cluster_admin_arns = [
    "arn:aws:iam::${local.account_id}:user/jenkins",
  ]

  tags = {
    Environment = local.environment
    Account     = local.account_id
  }
}
