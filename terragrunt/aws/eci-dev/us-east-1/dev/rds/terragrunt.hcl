include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../terraform-modules/aws/rds"
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
    vpc_id        = "vpc-00000000000000000"
    db_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    node_security_group_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name                       = "dev"
  vpc_id                     = dependency.vpc.outputs.vpc_id
  db_subnet_ids              = dependency.vpc.outputs.db_subnet_ids
  allowed_security_group_ids = [dependency.eks.outputs.node_security_group_id]

  db_name                 = "appdb"
  master_username         = "admin"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 7

  tags = {
    Environment = local.environment
    Account     = local.account_id
  }
}
