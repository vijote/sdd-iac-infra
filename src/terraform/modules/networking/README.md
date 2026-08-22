# VPC Networking Foundation Module

A provider-agnostic Terraform module for creating VPC networking foundation for Kubernetes clusters. Supports both AWS and MiniStack providers with identical functionality.

## Features

- ✅ **VPC Creation** with configurable CIDR blocks
- ✅ **Subnet Management** (1 public, 2 private subnets)
- ✅ **Internet Gateway** for public subnet access
- ✅ **Route Tables** with proper routing configuration
- ✅ **Security Groups** for Kubernetes components
- ✅ **Provider Agnostic** (AWS & MiniStack support)
- ✅ **Cost Optimized** (no NAT gateway)
- ✅ **Security First** (least-privilege defaults)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        VPC                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Public    │  │  Private 1  │  │  Private 2  │        │
│  │   Subnet    │  │   Subnet    │  │   Subnet    │        │
│  │             │  │             │  │             │        │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │        │
│  │ │Control  │ │  │ │Worker   │ │  │ │Worker   │ │        │
│  │ │Plane    │ │  │ │Node 1   │ │  │ │Node 2   │ │        │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │        │
│  │             │  │             │  │             │        │
│  │ ┌─────────┐ │  │             │  │             │        │
│  │ │Ingress  │ │  │             │  │             │        │
│  │ │Controller│ │  │             │  │             │        │
│  │ └─────────┘ │  │             │  │             │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│         │                   │                   │         │
│         └───────────────────┼───────────────────┘         │
│                             │                             │
│                    ┌─────────────┐                        │
│                    │   Internet  │                        │
│                    │   Gateway   │                        │
│                    └─────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## Usage

This module is designed to be called from environment-specific configurations. See the `../environments` directory for examples.

### Example Module Call

```hcl
module "vpc_networking" {
  source = "../../modules/networking"
  
  # Required
  environment  = "production"
  project_name = "my-k8s-cluster"
  aws_region   = "us-east-1"
  
  # Optional
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # Tags
  additional_tags = {
    Team = "platform"
    Env  = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name for tagging | `string` | `"development"` | no |
| project_name | Project name for tagging | `string` | `"sdd-infra"` | no |
| aws_region | AWS region | `string` | `"us-east-1"` | no |
| vpc_cidr | CIDR block for VPC | `string` | `"10.0.0.0/16"` | no |
| public_subnet_cidr | CIDR block for public subnet | `string` | `"10.0.1.0/24"` | no |
| private_subnet_cidrs | List of CIDR blocks for private subnets | `list(string)` | `["10.0.2.0/24", "10.0.3.0/24"]` | no |
| availability_zones | List of availability zones | `list(string)` | `[]` | no |
| enable_control_plane_sg | Create control plane security group | `bool` | `true` | no |
| enable_worker_node_sg | Create worker node security group | `bool` | `true` | no |
| enable_ingress_sg | Create ingress security group | `bool` | `true` | no |
| enable_dns_hostnames | Enable DNS hostnames in VPC | `bool` | `true` | no |
| enable_dns_support | Enable DNS support in VPC | `bool` | `true` | no |
| additional_tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| is_using_ministack | Is using MiniStack? | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_cidr_block | The CIDR block of the VPC |
| public_subnet_id | The ID of the public subnet |
| public_subnet_cidr | The CIDR block of the public subnet |
| private_subnet_ids | List of private subnet IDs |
| private_subnet_cidrs | List of private subnet CIDRs |
| internet_gateway_id | The ID of the internet gateway |
| public_route_table_id | The ID of the public route table |
| private_route_table_ids | List of private route table IDs |
| security_group_ids | Map of security group IDs |
| control_plane_security_group_id | The ID of the control plane security group |
| worker_node_security_group_id | The ID of the worker node security group |
| ingress_security_group_id | The ID of the ingress security group |

## Security Groups

The module creates three security groups:

1. **Control Plane**: For Kubernetes API server and etcd
2. **Worker Nodes**: For Kubernetes worker nodes
3. **Ingress**: For ingress controllers and load balancers

Each security group follows the principle of least privilege with specific rules for Kubernetes communication.

## Provider Configuration

This module does not contain provider configuration. Providers should be configured at the environment level to ensure proper separation of concerns and enable multi-environment deployments.