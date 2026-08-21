# MiniStack Environment Configuration
# Use this configuration for local development with MiniStack/LocalStack

# Project Configuration
project_name = "sdd-infra"
environment = "local"

# VPC Configuration (MiniStack - will be overridden by locals)
# These values are used as defaults but locals will apply MiniStack CIDRs
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidrs = [
  "10.0.2.0/24",
  "10.0.3.0/24"
]

# MiniStack doesn't use Availability Zones
availability_zones = []

# Security Groups (can be disabled for MiniStack testing)
enable_control_plane_sg = true
enable_worker_node_sg = true
enable_ingress_sg = true

# MiniStack Provider Configuration
aws_region = "local"

# MiniStack-specific settings
skip_credentials_validation = true
skip_metadata_api_check = true
skip_requesting_account_id = true
s3_use_path_style = true
ministack_endpoint = "http://localhost:4566"

# Tags
additional_tags = {
  Provider = "MiniStack"
  Environment = "development"
  CostCenter = "platform"
}