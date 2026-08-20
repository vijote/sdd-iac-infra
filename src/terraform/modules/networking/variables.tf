# Core Configuration Variables
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  
  validation {
    condition = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "sdd-infra"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# Subnet Configuration Variables
variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
  
  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Public subnet CIDR must be a valid CIDR block."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
  
  validation {
    condition = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly 2 private subnets must be specified."
  }
  
  validation {
    condition = alltrue([for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All private subnet CIDRs must be valid CIDR blocks."
  }
}

variable "availability_zones" {
  description = "List of availability zones (ignored for ministack)"
  type        = list(string)
  default     = []
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

# Advanced Configuration Variables
variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}