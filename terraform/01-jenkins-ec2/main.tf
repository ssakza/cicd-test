# ==================================================
# Jenkins EC2 인프라 - Terraform
# ==================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider 설정
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile  # ~/.aws/credentials의 프로필명
}

# 현재 IP 주소 자동 조회 (보안 그룹용)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip = "${chomp(data.http.my_ip.response_body)}/32"
}

# 기본 VPC 사용
data "aws_vpc" "default" {
  default = true
}

# 기본 서브넷 (첫 번째 AZ)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 최신 Amazon Linux 2023 AMI 자동 조회
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==================================================
# 보안 그룹
# ==================================================
resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = data.aws_vpc.default.id

  # SSH 접속 (본인 IP만)
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
  }

  # Jenkins 웹 UI (본인 IP만)
  ingress {
    description = "Jenkins UI from my IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
  }

  # 아웃바운드 전체 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

# ==================================================
# EC2 인스턴스
# ==================================================
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  # 스토리지 설정
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Jenkins 자동 설치 스크립트
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # 시스템 업데이트
              dnf update -y
              
              # Java 설치 (Jenkins 필수)
              dnf install -y java-17-amazon-corretto
              
              # Jenkins 저장소 추가
              wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
              
              # Jenkins 설치
              dnf install -y jenkins
              
              # Jenkins 서비스 시작
              systemctl enable jenkins
              systemctl start jenkins
              
              # Docker 설치 (04장에서 사용)
              dnf install -y docker
              systemctl enable docker
              systemctl start docker
              usermod -aG docker jenkins
              usermod -aG docker ec2-user
              
              # Git 설치
              dnf install -y git
              EOF

  tags = {
    Name        = "jenkins-server"
    Environment = "study"
    ManagedBy   = "terraform"
  }
}

# ==================================================
# Elastic IP (고정 IP) - 선택사항
# ==================================================
resource "aws_eip" "jenkins" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "jenkins-eip"
  }
}
