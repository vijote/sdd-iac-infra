# MiniStack Environment

This directory contains the Terraform configuration for deploying the networking module to MiniStack (LocalStack) for local development.

## Prerequisites

1. MiniStack/LocalStack running on localhost:4566
2. Docker installed and running

## Start MiniStack

```bash
# Using LocalStack Docker
docker run -d -p 4566:4566 localstack/localstack

# Or using MiniStack if you have it installed
ministack start
```

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

- **Region**: us-east-1 (any region works with MiniStack)
- **VPC CIDR**: 172.18.0.0/16 (MiniStack default range)
- **Public Subnet**: 172.18.1.0/24
- **Private Subnets**: 172.18.2.0/24, 172.18.3.0/24
- **Security Groups**: Control plane, worker nodes, and ingress
- **Endpoint**: http://localhost:4566

## Outputs

After deployment, you'll get:
- VPC ID
- Subnet IDs
- Security Group IDs
- Internet Gateway ID
- Route Table IDs

## Notes

- No AWS credentials required
- No actual AWS costs
- Resources exist only in local MiniStack instance
- Data persists only while MiniStack is running