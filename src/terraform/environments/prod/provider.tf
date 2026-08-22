provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
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

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}