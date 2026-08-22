# Development Environment Main Configuration
# This file instantiates all required modules for the dev environment

# Networking Module - Creates VPC, subnets, security groups
module "networking" {
  source = "../../modules/networking"

  # VPC Configuration
  vpc_cidr          = "10.0.0.0/16"
  environment       = "dev"
  project_name      = "sdd-infra"
  is_using_ministack = false
  aws_region        = var.aws_region

  # Subnet Configuration (using defaults from module)
  # Public subnets: 10.0.1.0/24, 10.0.2.0/24
  # Private subnets: 10.0.11.0/24, 10.0.12.0/24
}

# IAM Module - Creates IAM roles for Terraform operations
module "iam" {
  source = "../../modules/iam"

  environment    = "dev"
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region
}

# State Module - Creates S3 bucket and DynamoDB table for remote state
module "state" {
  source = "../../modules/state"

  environment          = "dev"
  aws_region           = var.aws_region
}

# Outputs for easy access to resource information
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.networking.public_subnet_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "control_plane_security_group_id" {
  description = "Control plane security group ID"
  value       = module.networking.control_plane_security_group_id
}

output "worker_node_security_group_id" {
  description = "Worker node security group ID"
  value       = module.networking.worker_node_security_group_id
}

output "ingress_security_group_id" {
  description = "Ingress security group ID"
  value       = module.networking.ingress_security_group_id
}

output "terraform_role_arn" {
  description = "Terraform dev role ARN"
  value       = module.iam.terraform_role_arn
}

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = module.state.state_bucket_name
}