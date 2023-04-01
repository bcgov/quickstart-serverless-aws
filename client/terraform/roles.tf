#CloudFront Roles

data "aws_iam_policy_document" "quickstart-frontend-s3-policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.quickstart-frontend.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.quickstart-frontend-oai.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.quickstart-frontend.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.quickstart-frontend-oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "quickstart-frontend-s3-policy" {
  bucket = aws_s3_bucket.quickstart-frontend.id
  policy = data.aws_iam_policy_document.quickstart-frontend-s3-policy.json
}
