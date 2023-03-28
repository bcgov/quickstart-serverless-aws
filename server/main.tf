terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
  }
}


provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
resource "aws_s3_bucket" "buckets" {
  #checkov:skip=CKV_AWS_18:Access logging is not required for sample application
  #checkov:skip=CKV2_AWS_6:S3 Block Public Access is automatically done by ASEA
  #checkov:skip=CKV_AWS_19:Obejct encryption is automatically done by ASEA
  #checkov:skip=CKV_AWS_144:Bucket replication is not required for sample application
  #checkov:skip=CKV_AWS_145:Bucket encryption is automatically done by ASEA
  for_each = toset(["upload-bucket", "lambda-bucket"])
  bucket   = "${each.key}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}
resource "aws_s3_bucket_versioning" "buckets" {
  for_each = toset(["upload-bucket", "lambda-bucket"])
  bucket   = aws_s3_bucket.buckets[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

data "archive_file" "hello_world_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/hello_world"
  output_path = "${path.module}/hello_world.zip"
}

resource "aws_s3_object" "hello_world_lambda_server" {
  bucket = aws_s3_bucket.buckets["lambda-bucket"].id
  key    = "hello_world.zip"
  source = data.archive_file.hello_world_lambda.output_path
  etag   = filemd5(data.archive_file.hello_world_lambda.output_md5)
  #checkov:skip=CKV_AWS_186:Encryption is automatically done by ASEA
}

resource "random_pet" "DB_NAME" {
  prefix = "ci-"
  length = 2
}


resource "aws_dynamodb_table" "terraform_state_lock" {
  name      = random_pet.DB_NAME.id
  hash_key  = "pid"
  range_key = "id"
  #checkov:skip=CKV_AWS_119:Encryption is managed by dynamodb
  billing_mode = "PAY_PER_REQUEST"
  # read_capacity  = 5
  # write_capacity = 5
  attribute {
    name = "pid"
    type = "S"
  }
  attribute {
    name = "id"
    type = "S"
  }
  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_iam_role_policy" "hello_world_lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_exec.id
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
          "Effect": "Allow",
          "Action": [
              "dynamodb:BatchGet*",
              "dynamodb:DescribeStream",
              "dynamodb:DescribeTable",
              "dynamodb:Get*",
              "dynamodb:Query",
              "dynamodb:Scan",
              "dynamodb:BatchWrite*",
              "dynamodb:CreateTable",
              "dynamodb:Delete*",
              "dynamodb:Update*",
              "dynamodb:PutItem"
          ],
          "Resource": "${aws_dynamodb_table.terraform_state_lock.arn}"
        },
        {
          "Effect": "Allow",
           "Action": [
                  "logs:CreateLogGroup",
                  "logs:CreateLogStream",
                   "kms:*",
                  "logs:PutLogEvents",
                  "logs:DescribeLogStreams"
              ],
          "Resource": "*"
      },
       {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:PutBucketCORS"
            ],
            "Resource": [
                "${aws_s3_bucket.buckets["upload-bucket"].arn}",
                "${aws_s3_bucket.buckets["upload-bucket"].arn}/*"
            ]
        }
    ]
  }
  EOF
}


data "aws_iam_policy_document" "lambda_exec_policydoc" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_exec_policydoc.json
}

resource "aws_lambda_function" "hello_world" {
  function_name = "hello_world"
  #checkov:skip=CKV_AWS_50:X-ray tracing is not required for this sample application
  #checkov:skip=CKV_AWS_116:DLQ(Dead Letter Queue) is not required for this sample application
  #checkov:skip=CKV_AWS_117:VPC Configuration is not required for the sample application function
  #checkov:skip=CKV_AWS_173:The environment variables below are encrypted at rest with the default Lambda service key.
  #checkov:skip=CKV_AWS_272: "Ensure AWS Lambda function is configured to validate code-signing"
  s3_bucket = aws_s3_bucket.buckets["lambda-bucket"].id
  s3_key    = aws_s3_object.hello_world_lambda_server.key
  runtime                        = "go1.x"
  handler                        = "./lambda.handler"
  reserved_concurrent_executions = -1

  source_code_hash = data.archive_file.hello_world_lambda.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      bucketName = aws_s3_bucket.buckets["upload-bucket"].id
      DB_NAME    = random_pet.DB_NAME.id
    }
  }

}


resource "aws_api_gateway_rest_api" "hello_world_api" {
  name = "hello_world_api"
  description = "API for hello world lambda function"
  lifecycle {
    create_before_destroy = true
  }

}


resource "aws_api_gateway_api_key" "hello_world_api_key" {
  name = "hello_world_api_key"
}
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  parent_id   = aws_api_gateway_rest_api.hello_world_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxyMethod" {
  rest_api_id   = aws_api_gateway_rest_api.hello_world_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true
  #checkov:skip=CKV_AWS_59:API_KEY authotization is not required for this sample application
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  resource_id = aws_api_gateway_method.proxyMethod.resource_id
  http_method = aws_api_gateway_method.proxyMethod.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_world.invoke_arn
}




resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.hello_world_api.id
  resource_id   = aws_api_gateway_rest_api.hello_world_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
  #checkov:skip=CKV_AWS_59:API_KEY authotization is not required for this sample application
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_world.invoke_arn
}


resource "aws_api_gateway_deployment" "apideploy" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  stage_name  = "test"
  lifecycle {
    create_before_destroy = true
  }

}


resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.hello_world_api.execution_arn}/*/*"
}


module "cors" {
  source  = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.hello_world_api.id
  api_resource_id = aws_api_gateway_resource.proxy.id


}
