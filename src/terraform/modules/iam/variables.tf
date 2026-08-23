variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  
  validation {
    condition     = can(regex("^\\d{12}$", var.aws_account_id))
    error_message = "AWS Account ID must be a 12-digit number."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_terraform_role_name" {
  description = "AWS Terraform Role NAME"
  type        = string
  default     = "terraform-role"
}

variable "aws_state_bucket_name" {
  description = "AWS S3 State Bucket"
  type        = string
  default     = "terraform-role"
}