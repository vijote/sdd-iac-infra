# VPC Networking Foundation - Basic Example

This example demonstrates how to use the VPC networking foundation module to create a complete network infrastructure for Kubernetes clusters.

## 🏗️ What This Creates

- **1 VPC** (10.0.0.0/16) with DNS support and hostname support
- **1 Public Subnet** (10.0.1.0/24) for internet-facing resources
- **2 Private Subnets** (10.0.2.0/24, 10.0.3.0/24) for Kubernetes nodes
- **1 Internet Gateway** for public subnet internet access
- **Route Tables** with appropriate routing rules
- **All resources tagged** with project and environment metadata

## 🚀 Quick Start

### Option 1: Production AWS Deployment

```bash
# Configure AWS credentials
aws configure

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Deploy the infrastructure
terraform apply
```

### Option 2: Local Testing with MiniStack/LocalStack

```bash
# Start MiniStack/LocalStack
# (See MiniStack/LocalStack documentation for setup)

# Set environment variables (recommended)
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export MINISTACK_ENDPOINT="http://localhost:4566"

# Or use the provided tfvars file
terraform init
terraform plan -var-file="ministack.tfvars"
terraform apply -var-file="ministack.tfvars"
```

### Option 3: Using AWS Profile

```bash
# Configure a named profile
aws configure --profile my-profile

# Use the profile
terraform init
terraform plan -var="aws_profile=my-profile"
terraform apply -var="aws_profile=my-profile"
```

## 📁 File Structure

```
basic/
├── main.tf              # Main configuration and module call
├── provider.tf          # AWS provider configuration (secure)
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── versions.tf          # Terraform and provider versions
├── ministack.tfvars     # MiniStack/LocalStack configuration
├── validate.sh          # Validation script
└── README.md           # This file
```

## 🔧 Configuration

### Core Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_cidr` | CIDR block for the VPC | `"10.0.0.0/16"` |
| `public_subnet_cidr` | CIDR for public subnet | `"10.0.1.0/24"` |
| `private_subnet_cidrs` | CIDRs for private subnets | `["10.0.2.0/24", "10.0.3.0/24"]` |
| `aws_region` | AWS region | `"us-west-2"` |
| `environment` | Environment name | `"development"` |
| `project_name` | Project name for tagging | `"sdd-infra"` |

### MiniStack/LocalStack Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_access_key` | Access key for local testing | `""` |
| `aws_secret_key` | Secret key for local testing | `""` |
| `ministack_endpoint` | MiniStack endpoint URL | `"http://localhost:4566"` |
| `skip_credentials_validation` | Skip credential validation | `false` |

## 📊 Outputs

The module outputs the following values:

- `vpc_id` - The VPC ID
- `vpc_cidr_block` - The VPC CIDR block
- `public_subnet_ids` - List of public subnet IDs
- `private_subnet_ids` - List of private subnet IDs
- `internet_gateway_id` - The Internet Gateway ID
- And more...

## 🔒 Security Considerations

- **No secrets stored in code** - All sensitive values use environment variables or secure input methods
- **Least privilege** - The module creates only the networking resources needed
- **Private subnets** - Kubernetes nodes are placed in private subnets by default
- **Cost optimized** - No NAT Gateways included by default (can be added when needed)

## 🧪 Validation

Run the validation script to check your configuration:

```bash
./validate.sh
```

This will:
- Check Terraform format and syntax
- Verify all required files exist
- Show what resources will be created

## 🧹 Cleanup

To destroy all created resources:

```bash
terraform destroy
```

## 📚 Next Steps

After deploying this networking foundation, you can:

1. **Deploy Kubernetes nodes** using the subnet IDs from outputs
2. **Add security groups** for Kubernetes control plane and worker nodes
3. **Set up IAM roles** for Kubernetes components
4. **Configure monitoring** and logging

## 🤝 Contributing

This example is part of the SDD-Infra project. Please follow the project's contribution guidelines when making changes.

## 📄 License

This project follows the license specified in the main repository.