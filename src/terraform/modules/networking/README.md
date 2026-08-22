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

## Providers

### AWS
- **Region**: Any AWS region (e.g., `us-east-1`)
- **CIDR**: `10.0.0.0/16` VPC, `10.0.1.0/24` public, `10.0.2.0/24` & `10.0.3.0/24` private
- **Features**: Full AWS service integration

### MiniStack
- **Region**: `local`
- **CIDR**: `172.18.0.0/16` VPC, `172.18.1.0/24` public, `172.18.2.0/24` & `172.18.3.0/24` private
- **Features**: Local development, no AWS costs

## Usage

### Basic AWS Deployment

```hcl
module "vpc_networking" {
  source = "./modules/networking"
  
  # Required
  environment  = "production"
  project_name = "my-k8s-cluster"
  aws_region   = "us-east-1"
  
  # Optional
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Team = "platform"
    Env  = "prod"
  }
}
```

### MiniStack Local Development

```hcl
module "vpc_networking" {
  source = "./modules/networking"
  
  # Required
  environment  = "development"
  project_name = "my-k8s-cluster"
  aws_region   = "local"  # This enables MiniStack
  
  # Optional
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name for tagging | `string` | `"development"` | no |
| `project_name` | Project name for tagging | `string` | `"sdd-infra"` | no |
| `aws_region` | AWS region (use 'local' for MiniStack) | `string` | `"us-east-1"` | no |
| `vpc_cidr` | CIDR block for VPC | `string` | `"10.0.0.0/16"` | no |
| `public_subnet_cidr` | CIDR block for public subnet | `string` | `"10.0.1.0/24"` | no |
| `private_subnet_cidrs` | CIDR blocks for private subnets | `list(string)` | `["10.0.2.0/24", "10.0.3.0/24"]` | no |
| `enable_dns_hostnames` | Enable DNS hostnames in VPC | `bool` | `true` | no |
| `enable_dns_support` | Enable DNS support in VPC | `bool` | `true` | no |
| `enable_control_plane_sg` | Create control plane security group | `bool` | `true` | no |
| `enable_worker_node_sg` | Create worker node security group | `bool` | `true` | no |
| `enable_ingress_sg` | Create ingress security group | `bool` | `true` | no |
| `additional_tags` | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | The ID of the VPC |
| `public_subnet_id` | The ID of the public subnet |
| `private_subnet_ids` | List of private subnet IDs |
| `internet_gateway_id` | The ID of the internet gateway |
| `control_plane_security_group_id` | The ID of the control plane security group |
| `worker_node_security_group_id` | The ID of the worker node security group |
| `ingress_security_group_id` | The ID of the ingress security group |

## Security Groups

### Control Plane Security Group
- **Port 6443/TCP**: kubelet API (from worker nodes)
- **Port 2379-2380/TCP**: etcd (control plane only)
- **Port 4789/UDP**: VXLAN overlay network (all nodes)

### Worker Node Security Group
- **Port 4789/UDP**: VXLAN overlay network (all nodes)
- **Port 30000-32767/TCP**: NodePort services (from ingress)

### Ingress Security Group
- **Port 80/TCP**: HTTP traffic (from internet)
- **Port 443/TCP**: HTTPS traffic (from internet)

## Examples

### Complete Production Example

```hcl
# Configure AWS provider
provider "aws" {
  region = var.aws_region
}

# Create VPC networking
module "networking" {
  source = "./modules/networking"
  
  environment  = "production"
  project_name = "my-company-k8s"
  aws_region   = "us-west-2"
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  additional_tags = {
    Team        = "platform"
    CostCenter  = "engineering"
    Owner       = "platform-team"
    Environment = "production"
  }
}

# Output important values
output "vpc_id" {
  value = module.networking.vpc_id
}

output "subnet_ids" {
  value = {
    public  = module.networking.public_subnet_id
    private = module.networking.private_subnet_ids
  }
}
```

### Development with MiniStack

```hcl
# Configure MiniStack provider
provider "aws" {
  region = "local"
  
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  endpoints {
    ec2 = "http://localhost:4566"
  }
}

# Create VPC networking for local development
module "networking" {
  source = "./modules/networking"
  
  environment  = "development"
  project_name = "my-k8s-dev"
  aws_region   = "local"
}
```

## Testing

The module includes comprehensive tests:

```bash
# Run all tests
go test ./tests/terraform/...

# Run specific test suites
go test ./tests/terraform/performance_test.go
go test ./tests/terraform/security_test.go
go test ./tests/terraform/connectivity_test.go
go test ./tests/terraform/provider_test.go
```

## Validation

The module includes built-in validation:

- **CIDR Validation**: Ensures valid CIDR blocks
- **Subnet Count**: Exactly 2 private subnets required
- **Region Validation**: Valid AWS region or 'local' for MiniStack
- **Port Validation**: Security group rules validated
- **IP Planning**: Ensures enough IPs for expected instances

## Provider Compatibility

| Feature | AWS | MiniStack |
|---------|-----|-----------|
| VPC Creation | ✅ | ✅ |
| Subnet Management | ✅ | ✅ |
| Security Groups | ✅ | ✅ |
| Route Tables | ✅ | ✅ |
| DNS Support | ✅ | ✅ |
| Resource Tagging | ✅ | ✅ |

For detailed compatibility information, see [Provider Compatibility Matrix](../../../docs/provider_compatibility.md).

## Security

This module follows security best practices:

- **Least Privilege**: Only required ports opened
- **Network Segmentation**: Public/private subnet separation
- **Security Groups**: Properly configured for Kubernetes
- **No Hardcoded Secrets**: All inputs through variables
- **Resource Tagging**: Complete tagging for access control

For detailed security information, see [Security Review](../../../docs/security_review.md).

## Cost Optimization

- **No NAT Gateway**: Cost savings on private subnet internet access
- **Single AZ**: Reduced complexity and cost (can be extended)
- **Minimal Resources**: Only required resources created
- **Local Development**: MiniStack provides zero-cost development

## Limitations

- **Single Availability Zone**: Current implementation uses single AZ
- **No NAT Gateway**: Private subnets have no internet access
- **No VPN**: Direct connectivity not implemented
- **MiniStack Scale**: Not suitable for production workloads

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests
5. Submit a pull request

## Version History

- **v1.0.0**: Initial release with AWS and MiniStack support
- **v1.1.0**: Added comprehensive validation and testing
- **v1.2.0**: Enhanced security features and documentation

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Documentation**: [Project Documentation](../../../docs/)
- **Issues**: [GitHub Issues](https://github.com/your-org/sdd-infra/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/sdd-infra/discussions)