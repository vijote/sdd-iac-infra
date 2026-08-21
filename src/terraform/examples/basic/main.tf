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

  # Core configuration (provider-agnostic)
  # Note: For MiniStack, set aws_region = "local" in terraform.tfvars
  # The module will automatically apply MiniStack-specific CIDRs
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  project_name = var.project_name
  aws_region   = var.aws_region

  # Subnet configuration
  # For MiniStack, these will be overridden with 172.18.0.0/16 CIDRs
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  # Security groups (can be disabled for MiniStack testing)
  enable_control_plane_sg = var.enable_control_plane_sg
  enable_worker_node_sg   = var.enable_worker_node_sg
  enable_ingress_sg       = var.enable_ingress_sg

  # Additional tags
  additional_tags = var.additional_tags
}

# Output provider information for verification
output "provider_info" {
  description = "Provider deployment information"
  value = {
    is_ministack = var.aws_region == "local"
    provider     = var.aws_region == "local" ? "MiniStack" : "AWS"
    region       = var.aws_region
  }
}