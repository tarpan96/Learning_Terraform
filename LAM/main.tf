terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.69.0"
    }
  }
}

provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = ""
}

data "aws_iam_policy_document" "iam-lam-tf" {
  statement {

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "test.pdf"
  output_path = "lambda_function_payload.zip"
}


resource "aws_iam_role" "role-lam-if" {
  name               = "iam-role-tf"
  assume_role_policy = data.aws_iam_policy_document.iam-lam-tf
}

resource "aws_lambda_function" "lam-tf" {
  role          = aws_iam_role.role-lam-if.arn
  filename      = "lambda_function_payload.zip"
  function_name = "lambda_zip_function"
  handler       = "index.test"
}
