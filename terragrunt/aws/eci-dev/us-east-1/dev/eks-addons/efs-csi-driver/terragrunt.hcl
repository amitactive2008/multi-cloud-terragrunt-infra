include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/aws/eks-addons/efs-csi-driver"
}

locals {
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_region   = local.region_vars.locals.aws_region
  account_id   = local.account_vars.locals.aws_account_id
  environment  = local.env_vars.locals.environment
}

dependency "eks" {
  config_path = "../../eks"
  mock_outputs = {
    cluster_name                  = "dev-eks"
    cluster_endpoint              = "https://mock.example.com"
    cluster_certificate_authority = "bW9jaw=="
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Ensures core (Pod Identity Agent) is deployed before this module
dependency "core" {
  config_path = "../core"
  mock_outputs = {
    pod_identity_agent_addon_arn = "arn:aws:eks:us-east-1:000000000000:addon/mock/eks-pod-identity-agent/mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "vpc" {
  config_path = "../../vpc"
  mock_outputs = {
    vpc_id             = "vpc-00000000"
    vpc_cidr_block     = "10.0.0.0/16"
    private_subnet_ids = ["subnet-00000001", "subnet-00000002"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name           = dependency.eks.outputs.cluster_name
  cluster_endpoint       = dependency.eks.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.eks.outputs.cluster_certificate_authority
  aws_region             = local.aws_region
  account_id             = local.account_id
  environment            = local.environment

  vpc_id             = dependency.vpc.outputs.vpc_id
  vpc_cidr           = dependency.vpc.outputs.vpc_cidr_block
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  efs_csi_driver_version = "v3.2.0-eksbuild.1"

  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"
  transition_to_ia = "AFTER_30_DAYS"

  tags = {
    Environment = local.environment
    Account     = local.account_id
  }
}
