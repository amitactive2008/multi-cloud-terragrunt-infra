include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/aws/eks-addons/pod-identity-s3"
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

inputs = {
  cluster_name           = dependency.eks.outputs.cluster_name
  cluster_endpoint       = dependency.eks.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.eks.outputs.cluster_certificate_authority
  aws_region             = local.aws_region
  account_id             = local.account_id
  environment            = local.environment

  s3_bucket_name            = "terraform-state-${local.account_id}"
  s3_access_namespace       = "default"
  s3_access_service_account = "s3-access-sa"

  tags = {
    Environment = local.environment
    Account     = local.account_id
  }
}
