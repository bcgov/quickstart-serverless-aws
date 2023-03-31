# read environment variables and set them as locals
locals {
  common_vars = yamldecode(file("common_vars.yaml"))
}

generate "remote_state" {
  path      = "backend.tf"
  if_exists = "overwrite"
  contents  = <<EOF
    terraform {
      backend "s3" {
        bucket = "${local.common_vars.bucket}"
        key = "${local.common_vars.key}"
        dynamodb_table = "${local.common_vars.dynamodb_table}"
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
