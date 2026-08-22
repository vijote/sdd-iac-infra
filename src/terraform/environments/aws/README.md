# AWS Environment

This directory contains the Terraform configuration for deploying the networking module to AWS cloud.

## Prerequisites

1. AWS CLI configured with valid credentials
2. Appropriate IAM permissions for creating VPC, subnets, and security groups

## Usage

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

## Configuration

- **Region**: us-east-1
- **VPC CIDR**: 10.0.0.0/16
- **Public Subnet**: 10.0.1.0/24 (us-east-1a)
- **Private Subnets**: 10.0.2.0/24, 10.0.3.0/24 (us-east-1a, us-east-1b)
- **Security Groups**: Control plane, worker nodes, and ingress

## Outputs

After deployment, you'll get:
- VPC ID
- Subnet IDs
- Security Group IDs
- Internet Gateway ID
- Route Table IDs