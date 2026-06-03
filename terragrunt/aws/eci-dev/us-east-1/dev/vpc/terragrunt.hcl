include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../terraform-modules/aws/vpc"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_id   = local.account_vars.locals.aws_account_id
  environment  = local.env_vars.locals.environment
}

inputs = {
  name       = "dev-vpc"
  cidr_block = "10.0.0.0/16"

  azs = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  db_subnet_cidrs      = ["10.0.21.0/24", "10.0.22.0/24"]
  es_subnet_cidrs      = ["10.0.31.0/24", "10.0.32.0/24"]

  tags = {
    Environment = local.environment
    Account     = local.account_id
  }

  eks_cluster_name = "dev-eks"
}
