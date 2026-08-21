# AWS Environment Configuration
# Use this configuration for deploying to AWS cloud

# Project Configuration
project_name = "sdd-infra"
environment = "aws"

# VPC Configuration (AWS)
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

# Security Groups (enabled by default for AWS)
enable_control_plane_sg = true
enable_worker_node_sg = true
enable_ingress_sg = true

# AWS Provider Configuration
aws_region = "us-east-1"

# Tags
additional_tags = {
  Provider = "AWS"
  Environment = "production"
  CostCenter = "platform"
}