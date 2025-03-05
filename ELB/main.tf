terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.63.0"
    }
  }
}

provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = ""
}
################### VPC ###################
resource "aws_vpc" "vit-piv-tf" {
  cidr_block = "10.0.0.0/23"
}

################### IGW ###################
resource "aws_internet_gateway" "ig-lb-tf" {
  vpc_id = aws_vpc.vit-piv-tf.id
}

################### RT ####################
resource "aws_route_table" "rt-pb1-tf" {
  vpc_id = aws_vpc.vit-piv-tf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig-lb-tf.id
  }
}

resource "aws_route_table" "rt-pv1-tf" {
  vpc_id = aws_vpc.vit-piv-tf.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.net-gtw-tf.id
  }
}

resource "aws_route_table_association" "rta-sub1-tf" {
  route_table_id = aws_route_table.rt-pb1-tf.id
  subnet_id      = aws_subnet.sub-pb1-tf.id
}

resource "aws_route_table_association" "rta-sub2-tf" {
  route_table_id = aws_route_table.rt-pb1-tf.id
  subnet_id      = aws_subnet.sub-pb2-tf.id
}

resource "aws_route_table_association" "rta-sub3-tf" {
  route_table_id = aws_route_table.rt-pv1-tf.id
  subnet_id      = aws_subnet.sub-pv1-tf.id
}

################### SUB ###################
resource "aws_subnet" "sub-pb1-tf" {
  vpc_id                  = aws_vpc.vit-piv-tf.id
  cidr_block              = "10.0.0.0/27"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_subnet" "sub-pb2-tf" {
  vpc_id                  = aws_vpc.vit-piv-tf.id
  cidr_block              = "10.0.0.32/27"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
}

resource "aws_subnet" "sub-pv1-tf" {
  vpc_id                  = aws_vpc.vit-piv-tf.id
  cidr_block              = "10.0.1.0/27"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
}

################### EIP ###################
resource "aws_eip" "eip-tf" {
  depends_on = [aws_internet_gateway.ig-lb-tf]
  tags = {
    Name = "e-ip-tf"
  }
}

################### NGW ###################
resource "aws_nat_gateway" "net-gtw-tf" {
  subnet_id     = aws_subnet.sub-pb1-tf.id
  allocation_id = aws_eip.eip-tf.id

  depends_on = [aws_internet_gateway.ig-lb-tf]
}

################### LB ####################
resource "aws_lb" "lb-tf" {
  name               = "lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sec-gp-lb-tf.id]
  subnets            = [aws_subnet.sub-pb1-tf.id, aws_subnet.sub-pb2-tf.id]
  depends_on         = [aws_internet_gateway.ig-lb-tf]
}

resource "aws_lb_target_group" "lb-tgp-tf" {
  name     = "lb-tgp-tf"
  vpc_id   = aws_vpc.vit-piv-tf.id
  port     = 80
  protocol = "HTTP"
}

resource "aws_lb_listener" "lb-lsnr-tf" {
  load_balancer_arn = aws_lb.lb-tf.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tgp-tf.arn
  }
}

################### EC2 ###################
resource "aws_launch_template" "ec2-template-tf" {
  name          = "ec2-tf"
  image_id      = "ami-066784287e358dad1"
  instance_type = "t2.micro"
  user_data     = filebase64("sh_httpd.sh")

  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = aws_subnet.sub-pv1-tf.id
    security_groups             = [aws_security_group.sec-gp-ec2-tf.id]
  }
}

resource "aws_autoscaling_group" "aut-scl-gp-tf" {
  min_size = 1
  max_size = 1

  target_group_arns = [aws_lb_target_group.lb-tgp-tf.arn]

  vpc_zone_identifier = [aws_subnet.sub-pv1-tf.id]

  launch_template {
    id = aws_launch_template.ec2-template-tf.id
  }
}

################### SGP ###################
resource "aws_security_group" "sec-gp-ec2-tf" {
  name   = "sec-gp-ec2-tf"
  vpc_id = aws_vpc.vit-piv-tf.id

  ingress {
    description      = "Allow only ELB traffic"
    protocol         = "tcp"
    to_port          = 80
    from_port        = 80
    cidr_blocks      = [aws_vpc.vit-piv-tf.cidr_block]
    security_groups  = [aws_security_group.sec-gp-lb-tf.id]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
  }

  egress {
    description = "Allow all outbound traffic "
    protocol    = "-1"
    to_port     = 0
    from_port   = 0
    cidr_blocks = [aws_vpc.vit-piv-tf.cidr_block]
  }
}

resource "aws_security_group" "sec-gp-lb-tf" {
  vpc_id = aws_vpc.vit-piv-tf.id
  name   = "sec-gp-lb-tf"
  ingress = [
    {
      description      = "Allow http request from anywhere"
      protocol         = "tcp"
      to_port          = 80
      from_port        = 80
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "Allow https request from anywhere"
      protocol         = "tcp"
      to_port          = 443
      from_port        = 443
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
  }]

  egress = [{
    description      = "Allow all outbound traffic "
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]
}
