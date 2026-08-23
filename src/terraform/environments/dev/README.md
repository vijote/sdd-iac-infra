# Development Environment

This directory contains Terraform configuration for the development environment.

## Configuration

- `backend.tf` - S3 backend configuration
- `provider.tf` - AWS provider configuration
- `terraform.tfvars` - Development-specific variables

## Usage

```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## Environment-Specific Settings

- Uses least-privilege IAM role for dev environment
- State stored in dev-specific S3 prefix
- Resource tagging with environment=dev