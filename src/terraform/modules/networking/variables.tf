# VPC Configuration Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC (will be overridden for MiniStack)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }

  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) <= 16
    error_message = "VPC CIDR must be /16 or larger (smaller number) for enterprise networks."
  }
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "development"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "Environment name must contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.environment) >= 3 && length(var.environment) <= 20
    error_message = "Environment name must be between 3 and 20 characters."
  }
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "sdd-infra"
}

variable "is_using_ministack" {
  description = "Is using ministack?"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region (use 'local' for MiniStack)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.is_using_ministack || can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must be a valid region name or 'local' for MiniStack."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet (will be overridden for MiniStack)"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Public subnet CIDR must be a valid CIDR block."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (will be overridden for MiniStack)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]

  validation {
    condition = alltrue([
      for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All private subnet CIDRs must be valid CIDR blocks."
  }

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly 2 private subnets are required per specification FR-004."
  }
}

variable "availability_zones" {
  description = "List of availability zones (not used for MiniStack)"
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

# DNS Configuration Variables
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

# MiniStack-specific Variables
variable "skip_credentials_validation" {
  description = "Skip AWS credentials validation (for MiniStack)"
  type        = bool
  default     = false
}

variable "skip_metadata_api_check" {
  description = "Skip metadata API check (for MiniStack)"
  type        = bool
  default     = false
}

variable "skip_requesting_account_id" {
  description = "Skip requesting account ID (for MiniStack)"
  type        = bool
  default     = false
}

variable "s3_use_path_style" {
  description = "Use path-style S3 URLs (for MiniStack)"
  type        = bool
  default     = false
}

variable "ministack_endpoint" {
  description = "MiniStack endpoint URL"
  type        = string
  default     = ""

  validation {
    condition     = var.ministack_endpoint == "" || can(regex("^https?://", var.ministack_endpoint))
    error_message = "MiniStack endpoint must be a valid URL starting with http:// or https://."
  }
}

# Edge case handling variables
variable "enable_cidr_conflict_check" {
  description = "Enable CIDR conflict validation between subnets"
  type        = bool
  default     = true
}

variable "max_instances_per_subnet" {
  description = "Maximum number of instances expected per subnet for IP planning"
  type        = number
  default     = 50

  validation {
    condition     = var.max_instances_per_subnet > 0 && var.max_instances_per_subnet <= 250
    error_message = "Max instances per subnet must be between 1 and 250."
  }
}