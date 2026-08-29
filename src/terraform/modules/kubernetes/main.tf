# Kubernetes Cluster Foundation Module
# Provisions a 3-node Kubernetes cluster (1 control plane, 2 workers)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS provider configuration
provider "aws" {
  region = var.aws_region
}

# Module dependencies
# These modules should be referenced when using this module
# VPC module (from Spec 001)
# Security module (from Spec 002)

# Data source for Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  key_name   = "${var.cluster_name}-ssh-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

# Control plane instance
resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.control_plane_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = var.security_group_ids
  user_data              = file("${path.module}/cloud-init/control-plane.yaml")
  key_name = aws_key_pair.k8s_key.key_name
  
  tags = {
    Name        = "${var.cluster_name}-control-plane"
    Environment = var.environment
    Cluster     = var.cluster_name
    Role        = "control-plane"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }
}

# Worker instances
resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  user_data = templatefile("${path.module}/cloud-init/worker.yaml", {
    CONTROL_PLANE_IP = aws_instance.control_plane.private_ip
  })

  tags = {
    Name        = "${var.cluster_name}-worker-${count.index + 1}"
    Environment = var.environment
    Cluster     = var.cluster_name
    Role        = "worker"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }
}