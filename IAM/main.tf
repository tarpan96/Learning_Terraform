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
  profile                  = ""
}

resource "aws_iam_user" "AlphaUser" {
  name = "AlphaUser"
}
resource "aws_iam_access_key" "AlphaAK" {
  user = aws_iam_user.AlphaUser.name
}

output "AlphaUserAccessKeyId" {
  value = aws_iam_access_key.AlphaAK.id
}

output "AlphaUserSecretAccessKey" {
  value     = aws_iam_access_key.AlphaAK.secret
  sensitive = true
}

resource "aws_iam_user_ssh_key" "userSSHKey" {
  username   = aws_iam_user.AlphaUser.name
  encoding   = "SSH"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDToBfUaZrC6xtyb8Z/yS6tISy702b+dvL2jqBcj8YXzIn8LT0BQ2lxzbIfGduQQm08dQFi/vV6ZQ7d8f/IamV4WeHkTgJ4ePMH1RZiEw8B0niCtjcmai1b0UG66QIb9oRXPgZlt9KU/TWdW7K5UzZ3pWuzKBo0GxSv5fWcN8jh3g6duHrCA0Z++Y0TX1oetTBRtEfyTAorcmbQZ2cIMc7i7htzHtWl+y8i60pTOlHND6ACuPsdVXY6ZRCKT6kZEOQDFhr1zZiTV7YoPP5J5Fzrd7MuPOUG1SitFDks3q5c9MBDVuZYgjQZjI26V5vOBX5HzxH261WUv6wgHwdBG2c8VTosdmczkNm4jTlf+j1sWOOBmbS19yPI5TrEW82v3MXzzqSYmQ4iJV03yN0+nLen+i5tXQbZkBlGxPOd1f7T9NAJf26qUqakd/Uf+LecotpkDcFJOhc7kJsAteBfAhyNUA21M+f1Pi9RM+HSJ+K+PxUy2HisMsbv8VtHcsbWtdkwh0ckIVU4oPFgjfzDhxuGQo9+yjJnx+5B4JcECBWXt3fbphWzMBVWhUe38UkxtUpVMgW+46/T/YPUSOugUuQHsqeTSzrUC/SBeBscRqUwUuFlagAZdlA2Os12qVbn4236ak1N7Jhf+iMIKSu6bQ3882L6txheFYoAO/opuE92EQ== tpatel@tpatel-mac"
}

resource "aws_iam_group" "AlphaGroup" {
  name = "AlphaGP"
}

resource "aws_iam_group_membership" "AlphaGPMems" {
  name  = "Dev Group"
  users = [aws_iam_user.AlphaUser.name]
  group = aws_iam_group.AlphaGroup.name
}

resource "aws_iam_role" "AlphaRole" {
  name = "Dev"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Principal = {
          AWS = "${aws_iam_user.AlphaUser.arn}"
        }
        Effect = "Allow"
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "AlphaPolicy" {
  name   = "Alpha-Polices"
  policy = data.aws_iam_policy_document.AlphaPDoc.json
}

data "aws_iam_policy_document" "AlphaPDoc" {
  statement {
    sid = "1"
    actions = [
      "ec2:*",
      "s3:*",
      "elasticloadbalancing:*"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_group_policy_attachment" "AttachPolicy" {
  policy_arn = aws_iam_policy.AlphaPolicy.arn
  group      = aws_iam_group.AlphaGroup.name

  depends_on = [
    aws_iam_group.AlphaGroup,
    aws_iam_policy.AlphaPolicy
  ]
}
