locals {
  # needs to be at the top of the file for each terragrunt.hcl file
  bucket         = get_env("client_bucket_name", "") # s3 backend bucket for terraform state
  key            = get_env("client_bucket_key", "") # s3 backend key for terraform state
  dynamodb_table = get_env("dynamo_db_table", "") # dynamodb table for terraform state locking
  app_version    = get_env("app_version", "") # frontend app version
  s3_bucket      = get_env("s3_bucket", "") # s3 bucket for frontend app
  origin_id      = get_env("origin_id", "") # cloudfront origin id
  target_env     = get_env("target_env", "") # target environment
}

terraform {
  source = "../../terraform///"
}


# read the parent folder's terragrunt.hcl file , which generic and environment agnostic.
include {
  path = find_in_parent_folders()
}


inputs = {
  app_version    = local.app_version
  s3_bucket      = local.s3_bucket
  target_env     = local.target_env
  #The below variables are used in the terraform scripts to store backend state in S3
  bucket         = local.bucket
  key            = local.key
  dynamodb_table = local.dynamodb_table
}
