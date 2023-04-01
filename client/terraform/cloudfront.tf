#bucket containing the static files to serve out, here naming is quickstart-frontend but it could be anything based on the app
resource "aws_s3_bucket" "quickstart-frontend" {
  bucket = "${var.s3_bucket}-${var.target_env}"
  tags   = {
    Name = var.s3_bucket_name
  }
}
resource "aws_s3_object" "quickstart-frontend-files" {
  # Enumerate all the files in ./src
  for_each = fileset(var.frontend_build_path, "**")

  #checkov:skip=CKV_AWS_186:S3 Encryption is automatically done by ASEA

  # Create an object from each
  bucket = aws_s3_bucket.quickstart-frontend.id
  key    = each.value
  source = "${var.frontend_build_path}/${each.value}"

  content_type = lookup(var.content_type_map, regex("\\.(?P<extension>[A-Za-z0-9]+)$", each.value).extension, "application/octet-stream")
}

resource "aws_s3_bucket_acl" "quickstart-frontend-acl" {
  bucket = "${var.s3_bucket}-${var.target_env}"
  acl    = "private"
}

#bucket to hold cloudfront logs
resource "aws_s3_bucket" "quickstart-frontend-logs" {
  bucket = "${var.s3_bucket}-logs-${var.target_env}"

  tags   = {
    Name = "${var.s3_bucket_name} Logs"
  }
}

resource "aws_s3_bucket_acl" "quickstart-frontend-logs-acl" {
  bucket = "${var.s3_bucket}-logs-${var.target_env}"
  acl    = "private"
}

#Access ID so CF can read the non-public bucket containing static site files
resource "aws_cloudfront_origin_access_identity" "quickstart-frontend-oai" {
  comment = "Cloud front OAI for quickstart-frontend"
}

#setup a cloudfront distribution to serve out the frontend files from s3 (github actions will push builds there)
resource "aws_cloudfront_distribution" "s3_web_distribution" {
  wait_for_deployment = true
  origin {
    domain_name = aws_s3_bucket.quickstart-frontend.bucket_regional_domain_name
    origin_id   = "${var.origin_id}-${var.target_env}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.quickstart-frontend-oai.cloudfront_access_identity_path
    }
  }


  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.quickstart-frontend-logs.bucket_domain_name
    prefix          = "logs"
  }

  custom_error_response {
    error_code    = 404
    response_code = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code    = 403
    response_code = 200
    response_page_path = "/index.html"
  }


  ordered_cache_behavior {
    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD"]
    path_pattern           = "/*"
    target_origin_id       = "${var.origin_id}-${var.target_env}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.origin_id}-${var.target_env}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["BY", "CF", "CN", "CD", "IR", "IQ", "KP", "LB", "LY", "ML", "MM", "NI", "RU", "SO", "SS", "SD", "SY", "UA", "VE", "YE", "ZW"]
    }
  }

  tags = {
    Environment = var.target_env
  }

  # Not using vanity
  dynamic "viewer_certificate" {
    for_each = var.enable_vanity_domain ? [] : [1]

    content {
      cloudfront_default_certificate = true
    }
  }

  # Using vanity
  dynamic "viewer_certificate" {
    for_each = var.enable_vanity_domain ? [1] : []

    content {
      acm_certificate_arn = var.vanity_domain_certs_arn
      ssl_support_method = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  aliases = var.vanity_domain
}
