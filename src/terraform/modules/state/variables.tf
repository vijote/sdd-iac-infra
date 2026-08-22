variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_state_bucket_name" {
  description = "S3 state bucket name"
  type        = string
  default     = "terraform-state"
}


variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}