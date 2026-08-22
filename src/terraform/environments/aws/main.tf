# AWS Environment Configuration
# This configuration deploys the networking module to AWS cloud

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Call the networking module
module "vpc_networking" {
  source = "../../modules/networking"
  
  # AWS Configuration
  aws_region = "us-east-1"
  
  # Project Configuration
  project_name = "sdd-infra"
  environment = "aws"
  
  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  private_subnet_cidrs = [
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
  
  # AWS Availability Zones
  availability_zones = [
    "us-east-1a",
    "us-east-1b"
  ]
  
  # Security Groups
  enable_control_plane_sg = true
  enable_worker_node_sg = true
  enable_ingress_sg = true
  
  # DNS Settings
  enable_dns_hostnames = true
  enable_dns_support = true
  
  # Tags
  additional_tags = {
    Provider = "AWS"
    Environment = "production"
    CostCenter = "platform"
  }
}