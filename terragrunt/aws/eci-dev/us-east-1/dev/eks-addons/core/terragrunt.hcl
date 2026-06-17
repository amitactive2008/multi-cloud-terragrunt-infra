include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/aws/eks-addons/core"
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

inputs = {
  cluster_name           = dependency.eks.outputs.cluster_name
  cluster_endpoint       = dependency.eks.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.eks.outputs.cluster_certificate_authority
  aws_region             = local.aws_region
  account_id             = local.account_id
  environment            = local.environment

  coredns_version        = "v1.14.2-eksbuild.4"
  kube_proxy_version     = "v1.36.0-eksbuild.2"
  vpc_cni_version        = "v1.21.1-eksbuild.8"
  metrics_server_version = "3.12.2"

  tags = {
    Environment = local.environment
    Account     = local.account_id
  }
}
