# Staging Environment

This directory contains Terraform configuration for the staging environment.

## Configuration

- `backend.tf` - S3 and DynamoDB backend configuration
- `provider.tf` - AWS provider configuration
- `terraform.tfvars` - Staging-specific variables

## Usage

```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## Environment-Specific Settings

- Uses least-privilege IAM role for staging environment
- State stored in staging-specific S3 prefix
- Resource tagging with environment=staging
- Manual approval may be required based on STAGING_APPROVAL_REQUIRED secret

## Deployment Process

1. Changes are deployed via GitHub Actions
2. Pull requests trigger terraform plan
3. Merge to main branch triggers terraform apply
4. Optional manual approval based on configuration

## State Management

- Remote state stored in S3 with encryption
- State locking via DynamoDB
- Versioning enabled for state recovery
- Automatic backups retained for 90 days