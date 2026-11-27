terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

resource "aws_security_group" "app_sg" {
  name        = "Resume-Coach-cicd-app-sg"
  description = "App server for the Resume Coach CI/CD pipeline - all traffic, like the class setup"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami                    = "ami-05d0b65183441f988"
  instance_type          = "t3.small"
  key_name               = "Resume-Coach-cicd-key"
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name    = "Resume-Coach-cicd-app-server"
    Project = "ENSF 519 Final Project"
    Purpose = "App server - runs the Docker container and Kubernetes"
  }
}

output "public_ip" {
  value = aws_instance.app_server.public_ip
}
