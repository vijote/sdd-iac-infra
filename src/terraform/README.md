# Terraform Infrastructure

This directory contains the Terraform configurations for deploying infrastructure to multiple environments.

## Directory Structure

```
terraform/
├── environments/
│   ├── aws/          # AWS cloud deployment
│   └── ministack/    # Local MiniStack deployment
└── modules/
    └── networking/    # Reusable VPC networking module
```

## Quick Start

### Deploy to AWS (Production)

```bash
cd environments/aws
terraform init
terraform apply
```

### Deploy to MiniStack (Local Development)

```bash
cd environments/ministack
terraform init
terraform apply
```

## Architecture

The networking module creates:
- VPC with configurable CIDR
- 1 public subnet
- 2 private subnets
- Internet gateway
- Route tables
- Security groups for Kubernetes components

## Environment Differences

| Feature | AWS | MiniStack |
|---------|-----|-----------|
| Region | us-east-1 | Any (uses localhost) |
| VPC CIDR | 10.0.0.0/16 | 172.18.0.0/16 |
| Credentials | Required | Not required |
| Cost | Actual AWS costs | Free (local) |
| Persistence | Permanent | While MiniStack runs |

## Module Design

The networking module is:
- **Provider-agnostic**: No provider configuration
- **Reusable**: Works with any AWS-compatible provider
- **Flexible**: Configurable CIDRs, tags, and features
- **Secure**: Least-privilege security group defaults