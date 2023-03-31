terraform {
  source = "../../terraform"
}

locals {
  common_vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
}

# read the parent folder's terragrunt.hcl file , which generic and environment agnostic.
include {
  path = find_in_parent_folders()
}


# generate a test.auto.tfvars file with the environment variables, so that terraform can read them and use them
generate "test_tfvars" {
  path              = "test.auto.tfvars"
  if_exists         = "overwrite"
  disable_signature = true
  contents          = <<-EOF
    app_version = "${local.common_vars.app_version}"
    s3_bucket = "${local.common_vars.s3_bucket}"
    origin_id = "${local.common_vars.origin_id}"
    api_gateway_origin_domain = "${local.common_vars.api_gateway_origin_domain}"
    api_gateway_origin_id = "${local.common_vars.api_gateway_origin_id}"
    api_gateway_path_pattern = "${local.common_vars.api_gateway_path_pattern}"
  EOF
}
