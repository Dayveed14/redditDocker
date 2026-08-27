terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "redditbackenddocker"
    key            = "api-deploy/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key"
}

resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "${var.aws_region}a"
}

resource "aws_security_group" "api_sg" {
  name        = "docker-api-security-group"
  description = "Allow SSH and Dockerized API traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
# HTTP Access
    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "docker-api-sg"
  }
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "docker-api-key"
  public_key = var.ssh_public_key
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "api_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.deployer_key.key_name
  subnet_id                   = aws_default_subnet.default_az1.id
  vpc_security_group_ids      = [aws_security_group.api_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
apt-get update -y

apt-get install -y docker.io git

systemctl enable docker
systemctl start docker

usermod -aG docker ubuntu

mkdir -p /home/ubuntu/api
chown -R ubuntu:ubuntu /home/ubuntu/api
EOF

  tags = {
    Name = "my-docker-api-instance"
  }
}

output "ec2_public_ip" {
  value = aws_instance.api_server.public_ip
}

output "ec2_public_dns" {
  value = aws_instance.api_server.public_dns
}
