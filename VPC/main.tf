terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.74.0"
    }
  }
}

provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = ""
}

######################### VPC #########################
resource "aws_vpc" "vpc-tf" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vpc-tf"
  }
}

resource "aws_internet_gateway" "internet-tf" {
  vpc_id = aws_vpc.vpc-tf.id
  tags = {
    Name = "internet-tf"
  }
}

resource "aws_subnet" "subnet-tf" {
  vpc_id     = aws_vpc.vpc-tf.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "subnet-tf"
  }
}

resource "aws_route_table" "route-table-tf" {
  vpc_id = aws_vpc.vpc-tf.id
  tags = {
    Name = "rtable-tf"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.route-table-tf.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet-tf.id
}

resource "aws_route_table_association" "rtb-assc-tf" {
  route_table_id = aws_route_table.route-table-tf.id
  subnet_id      = aws_subnet.subnet-tf.id
}

resource "aws_network_acl" "nacl-tf" {
  vpc_id     = aws_vpc.vpc-tf.id
  subnet_ids = [aws_subnet.subnet-tf.id]
  tags = {
    Name = "nacl-tf"
  }
}

resource "aws_network_acl_rule" "nacl-inbd1-tf" {
  network_acl_id = aws_network_acl.nacl-tf.id
  cidr_block     = "0.0.0.0/0"
  rule_action    = "allow"
  rule_number    = 100
  protocol       = "tcp"
  from_port      = 22
  to_port        = 22
  egress         = false
}

resource "aws_network_acl_rule" "nacl-inbd2-tf" {
  network_acl_id = aws_network_acl.nacl-tf.id
  cidr_block     = "0.0.0.0/0"
  rule_action    = "allow"
  rule_number    = 102
  protocol       = "tcp"
  from_port      = 443
  to_port        = 443
  egress         = false
}

resource "aws_network_acl_rule" "nacl-oubd-tf" {
  network_acl_id = aws_network_acl.nacl-tf.id
  cidr_block     = "0.0.0.0/0"
  rule_action    = "allow"
  rule_number    = 101
  protocol       = "-1"
  from_port      = 0
  to_port        = 0
  egress         = true
}

resource "aws_security_group" "asg-tf" {
  vpc_id = aws_vpc.vpc-tf.id
  tags = {
    Name = "asg-tf"
  }
}

resource "aws_security_group_rule" "asg-inbd-tf" {
  security_group_id = aws_security_group.asg-tf.id
  description       = "SSH"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "asg-inbd2-tf" {
  security_group_id = aws_security_group.asg-tf.id
  description       = "HTTPS"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "asg-inbd3-tf" {
  security_group_id = aws_security_group.asg-tf.id
  description       = "HTTP"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "asg-oubd-tf" {
  security_group_id = aws_security_group.asg-tf.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}


######################### EC2 #########################
resource "aws_instance" "ec2-tf" {
  ami                         = "ami-0866a3c8686eaeeba"
  subnet_id                   = aws_subnet.subnet-tf.id
  associate_public_ip_address = "true"
  instance_type               = "t2.micro"
  user_data                   = file("install_nginx.sh")
  security_groups             = [aws_security_group.asg-tf.id]
  tags = {
    Name = "ec2-tf"
  }
  key_name = aws_key_pair.tf-EC2Key.key_name
}

resource "tls_private_key" "tf-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "tf-EC2Key" {
  key_name   = "ec2-tf-key"
  public_key = tls_private_key.tf-key.public_key_openssh
}

output "private_key" {
  value     = tls_private_key.tf-key.private_key_pem
  sensitive = true
}

resource "aws_ami_from_instance" "image-ec2" {
  name               = "ec2-tf-AMI"
  source_instance_id = aws_instance.ec2-tf.id
}

######################### S3B #########################

resource "aws_s3_bucket" "s3b-tf" {
  bucket = "s3btp-tf"
}

resource "aws_s3_access_point" "s3ap-tf" {
  name   = "s3bap-tf"
  bucket = aws_s3_bucket.s3b-tf.id

  vpc_configuration {
    vpc_id = aws_vpc.vpc-tf.id
  }
}

resource "aws_s3_bucket_ownership_controls" "s3b-ows-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "s3-acl-tf" {
  depends_on = [aws_s3_bucket_ownership_controls.s3b-ows-tf]
  bucket     = aws_s3_bucket.s3b-tf.id
  acl        = "private"
}

resource "aws_s3_bucket_versioning" "s3b-ver-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "s3-olc-tf" {
  depends_on = [aws_s3_bucket_versioning.s3b-ver-tf]
  bucket     = aws_s3_bucket.s3b-tf.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 1
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3b-sec-tf" {
  bucket = aws_s3_bucket.s3b-tf.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

######################## OUTPUT #######################

resource "local_file" "ansible_host_file" {
  content  = <<EOF
${aws_instance.ec2-tf.public_ip}
EOF
  filename = "./hosts"
}

resource "local_file" "ansible_key_file" {
  content         = <<EOF
  ${tls_private_key.tf-key.private_key_pem}
EOF
  filename        = ""
  file_permission = "0400"
}
