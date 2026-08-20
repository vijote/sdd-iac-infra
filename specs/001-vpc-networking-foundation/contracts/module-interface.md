# Module Interface Contract: VPC Networking Foundation

**Date**: 2026-08-20  
**Module**: `terraform/modules/networking`

## Input Variables (Required)

### Core Configuration
```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
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
```

### Subnet Configuration
```hcl
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
  description = "List of availability zones (ignored for ministack)"
  type        = list(string)
  default     = []
}
```

### Security Group Configuration
```hcl
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
```

## Input Variables (Optional)

### Advanced Configuration
```hcl
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
```

## Output Values

### VPC Outputs
```hcl
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_main_route_table_id" {
  description = "ID of the main route table"
  value       = aws_vpc.main.main_route_table_id
}
```

### Subnet Outputs
```hcl
output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = aws_subnet.public.cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}
```

### Security Group Outputs
```hcl
output "control_plane_security_group_id" {
  description = "ID of the control plane security group"
  value       = aws_security_group.control_plane[0].id
}

output "worker_node_security_group_id" {
  description = "ID of the worker node security group"
  value       = aws_security_group.worker_node[0].id
}

output "ingress_security_group_id" {
  description = "ID of the ingress security group"
  value       = aws_security_group.ingress[0].id
}
```

### Internet Gateway Outputs
```hcl
output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = aws_internet_gateway.main.id
}
```

## Usage Examples

### Basic Usage
```hcl
module "networking" {
  source = "../../modules/networking"
  
  vpc_cidr           = "10.0.0.0/16"
  environment        = "development"
  project_name       = "sdd-infra"
  public_subnet_cidr = "10.0.1.0/24"
  private_subnet_cidrs = [
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
}
```

### Production Usage
```hcl
module "networking" {
  source = "../../modules/networking"
  
  vpc_cidr           = "10.0.0.0/16"
  environment        = "production"
  project_name       = "sdd-infra"
  availability_zones = ["us-west-2a", "us-west-2b"]
  
  additional_tags = {
    Owner       = "platform-team"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}
```

## Provider Requirements

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  
  required_version = ">= 1.5"
}
```

## Dependencies

- AWS Provider 5.0+
- Terraform 1.5+
- Appropriate AWS credentials configured
- S3 backend for state management (production)

## Constraints

### Resource Limits
- Maximum 3 subnets (1 public, 2 private)
- Single VPC per module instance
- Security groups are created within the same VPC

### Network Constraints
- CIDR blocks must not overlap
- Public subnet must have internet gateway route
- Private subnets use local routing only

### Tag Constraints
- All resources are tagged with required tags
- Additional tags are merged with required tags
- Tag keys must follow AWS naming conventions

## Error Handling

### Validation Errors
- Invalid CIDR blocks will cause Terraform validation failure
- Invalid environment values will trigger variable validation
- Overlapping CIDRs will be detected during planning

### Runtime Errors
- Insufficient AWS permissions will cause apply failure
- Resource limits exceeded will be reported by AWS
- Network conflicts will be detected during resource creation