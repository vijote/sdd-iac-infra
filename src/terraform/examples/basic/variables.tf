variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS profile name (alternative to access keys)"
  type        = string
  default     = ""
}

# MiniStack/LocalStack Configuration Variables
variable "aws_access_key" {
  description = "AWS access key (for MiniStack/LocalStack testing)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key (for MiniStack/LocalStack testing)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ministack_endpoint" {
  description = "MiniStack/LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}

variable "skip_credentials_validation" {
  description = "Skip AWS credentials validation (for MiniStack/LocalStack)"
  type        = bool
  default     = false
}

variable "skip_metadata_api_check" {
  description = "Skip metadata API check (for MiniStack/LocalStack)"
  type        = bool
  default     = false
}

variable "skip_requesting_account_id" {
  description = "Skip requesting account ID (for MiniStack/LocalStack)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "sdd-infra"
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Security Group Configuration Variables
variable "enable_control_plane_sg" {
  description = "Create control plane security group"
  type        = bool
  default     = true
}

variable "enable_worker_node_sg" {
  description = "Create worker node security group"
  type        = bool
  default     = true
}

variable "enable_ingress_sg" {
  description = "Create ingress security group"
  type        = bool
  default     = true
}

variable "s3_use_path_style" {
  description = "Use path-style S3 URLs (for MiniStack)"
  type        = bool
  default     = false
}