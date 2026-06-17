include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../../terraform-modules/aws/eks-addons/external-dns"
}

locals {
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_region   = local.region_vars.locals.aws_region
  account_id   = local.account_vars.locals.aws_account_id
  environment  = local.env_vars.locals.environment

  # External DNS configuration for linuxworms.in
  external_dns_config = {
    zone_ids       = ["Z00208349B1KPAQN1J8J"]
    domain_filters = ["linuxworms.in"]
    txt_owner_id   = "dev-eks-linuxworms"
  }
}

dependency "vpc" {
  config_path = "../../vpc"
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
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

  # External DNS specific configuration
  external_dns_namespace = "external-dns"
  create_namespace       = false
  
  # Route53 configuration for linuxworms.in
  route53_zone_ids       = local.external_dns_config.zone_ids
  route53_domain_filters = local.external_dns_config.domain_filters
  txt_owner_id           = local.external_dns_config.txt_owner_id

  # Helm configuration
  external_dns_version = "1.15.0"
  policy              = "sync"
  replicas            = 1
  log_level           = "info"
  interval            = "1m"
  trigger_loop_on_event = true
  sources             = ["ingress", "service"]

  tags = {
    Terraform   = "true"
    Environment = local.environment
  }
}
