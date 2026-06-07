locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  aws_account_id = local.account_vars.locals.aws_account_id
  aws_region = local.region_vars.locals.aws_region
  environment = local.env_vars.locals.environment
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region  = "${local.aws_region}"
  profile = "jenkins"

  assume_role {
    role_arn = "arn:aws:iam::${local.aws_account_id}:role/terraform"
  }
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket       = "terraform-state-${local.aws_account_id}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
    profile      = "jenkins"
    assume_role = {
      role_arn = "arn:aws:iam::${local.aws_account_id}:role/terraform"
    }
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
