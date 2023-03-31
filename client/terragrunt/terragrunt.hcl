# read environment variables and set them as locals
locals {
  # needs to be at the top of the file for each terragrunt.hcl file
  bucket         = get_env("client_bucket_name", "") # s3 backend bucket for terraform state
  key            = get_env("client_bucket_key", "") # s3 backend key for terraform state
  dynamodb_table = get_env("dynamo_db_table", "") # dynamodb table for terraform state locking
}

generate "remote_state" {
  path      = "backend.tf"
  if_exists = "overwrite"
  contents  = <<EOF
    terraform {
      backend "s3" {
        bucket = "${local.bucket}"
        key = "${local.key}"
        dynamodb_table = "${local.dynamodb_table}"
      }
    }
  EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
    provider "aws" {
      region  = "ca-central-1"
    }
  EOF
}
