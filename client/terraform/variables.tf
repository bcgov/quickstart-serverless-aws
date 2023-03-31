variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ca-central-1"
}

variable "target_env" {
  description = "AWS workload account env (e.g. dev, test, prod, sandbox, unclass)" # PR for sandbox
}

variable "frontend_build_path" {
  description = "Path to frontend build files"
  type        = string
  validation {
    condition     = length(fileset(var.frontend_build_path, "**")) > 0
    error_message = "The frontend build path must contain at least one file."
  }
}

variable "s3_bucket_name" {
  description = "Human readable S3 bucket name for labels"
  type        = string
  default     = "Quickstart Frontend App"
}
variable "content_type_map" {
  description = "Map of file extensions to content types"
  type        = map(string)
  default     = {
    "css"  = "text/css"
    "html" = "text/html"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "svg"  = "image/svg+xml"
    "txt"  = "text/plain"
    "xml"  = "text/xml"
  }
}

variable "origin_id" {
  description = "Origin Id"
  type        = string
  default     = "quickstart-frontend"
}

variable "budget_amount" {
  description = "The amount of spend for the budget. Example: enter 100 to represent $100"
  default     = "10.0"
}

variable "common_tags" {
  description = "Common tags for created resources"
  default     = {
    Application = "Quickstart Frontend App"
  }
}

variable "app_version" {
  description = "app version to deploy"
  type        = string
}

variable "s3_bucket" {
  description = "S3 Bucket containing static web files for CloudFront distribution"
  type        = string
}

variable "enable_vanity_domain" {
  description = "Enable public vanity domain"
  default     = false
}

variable "vanity_domain" {
  description = "Public vanity domain"
  default     = []
}

variable "vanity_domain_certs_arn" {
  description = "Public vanity domain certs ARN"
  default     = ""
}
