provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "sdd-infra"
      ManagedBy   = "terraform"
    }
  }
}

# Variables for provider configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_state_bucket_name" {
  description = "AWS S3 State Bucket"
  type        = string
}

variable "aws_terraform_role" {
  description = "AWS Terraform Role"
  type        = string
}