# AWS Provider Configuration
# This file is designed for public repositories - no secrets stored here

provider "aws" {
  region = var.aws_region
  
  # For local development with MiniStack/LocalStack, uncomment and set environment variables:
  # export AWS_ACCESS_KEY_ID="test"
  # export AWS_SECRET_ACCESS_KEY="test"
  # export MINISTACK_ENDPOINT="http://localhost:4566"
  #
  # Then uncomment the block below:
  # access_key                  = var.aws_access_key
  # secret_key                  = var.aws_secret_key
  # s3_use_path_style           = true
  # skip_credentials_validation = var.skip_credentials_validation
  # skip_metadata_api_check     = var.skip_metadata_api_check
  # skip_requesting_account_id  = var.skip_requesting_account_id
  # 
  # endpoints {
  #   s3       = var.ministack_endpoint
  #   sqs      = var.ministack_endpoint
  #   dynamodb = var.ministack_endpoint
  #   lambda   = var.ministack_endpoint
  # }
}

# Alternative: Use AWS profile from environment
# provider "aws" {
#   region  = var.aws_region
#   profile = var.aws_profile
# }