terraform {
  source = "..//..//terraform"
}

locals {
  common_vars = yamldecode(file(find_in_parent_folders("common-vars.yaml")))
}

# read the parent folder's terragrunt.hcl file , which generic and environment agnostic.
include {
  path = find_in_parent_folders()
}


inputs = {
  app_version    = local.common_vars.app_version
  s3_bucket      = local.common_vars.s3_bucket
  target_env     = local.common_vars.target_env
  #The below variables are used in the terraform scripts to store backend state in S3
  bucket         = local.common_vars.bucket
  key            = local.common_vars.key
  dynamodb_table = local.common_vars.dynamodb_table
}
