data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "web_distribution" {
  statement {
    actions = ["s3:GetObject"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.quickstart-frontend-oai.iam_arn]
    }
    resources = ["${aws_s3_bucket.quickstart-frontend.arn}/*"]
  }
}

