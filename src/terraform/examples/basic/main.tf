terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Provider configuration moved to provider.tf for better organization

# Call the networking module
module "networking" {
  source = "../../modules/networking"

  # Core configuration
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  project_name = var.project_name

  # Subnet configuration
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  # Security groups
  enable_control_plane_sg = true
  enable_worker_node_sg   = true
  enable_ingress_sg       = true

  # Additional tags
  additional_tags = var.additional_tags
}