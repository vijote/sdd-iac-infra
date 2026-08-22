variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "state_bucket_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  default     = "terraform-state"
}


variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}