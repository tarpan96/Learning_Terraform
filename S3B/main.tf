terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.59.0"
    }
  }
}

provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "terraform-aws"
}

resource "aws_s3_bucket" "s3b-tf" {
  bucket = "tp-0824-tf"
}

resource "aws_s3_bucket_acl" "s3b-acl-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "s3-ver-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "s3b-own-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_object" "s3b-upld-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  key    = "Testfile"
  source = "test.txt"
}

resource "aws_s3_bucket_accelerate_configuration" "example" {
  bucket = aws_s3_bucket.s3b-tf.id
  status = "Suspended"
}

resource "aws_s3_bucket_object_lock_configuration" "s3b-config-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 1
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3b-encrypted-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


