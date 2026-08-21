# AWS Provider Configuration
# This file is designed for public repositories - no secrets stored here

provider "aws" {
  region = var.aws_region
  
  # Provider-agnostic configuration
  # Automatically configures for MiniStack when aws_region = "local"
  
  # MiniStack configuration (conditional)
  access_key                  = var.aws_region == "local" ? "test" : null
  secret_key                  = var.aws_region == "local" ? "test" : null
  s3_use_path_style           = var.s3_use_path_style
  skip_credentials_validation = var.skip_credentials_validation
  skip_metadata_api_check     = var.skip_metadata_api_check
  skip_requesting_account_id  = var.skip_requesting_account_id
  
  # MiniStack endpoints (only when using local region)
  dynamic "endpoints" {
    for_each = var.aws_region == "local" ? [1] : []
    content {
      s3       = var.ministack_endpoint
      sqs      = var.ministack_endpoint
      dynamodb = var.ministack_endpoint
      lambda   = var.ministack_endpoint
      ec2      = var.ministack_endpoint
      iam      = var.ministack_endpoint
    }
  }
  
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Module    = "networking"
    }
  }
}

# Alternative: Use AWS profile from environment
# provider "aws" {
#   region  = var.aws_region
#   profile = var.aws_profile
# }