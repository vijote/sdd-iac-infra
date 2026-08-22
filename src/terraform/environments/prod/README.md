# Production Environment

This directory contains Terraform configuration for the production environment.

## Configuration

- `backend.tf` - S3 and DynamoDB backend configuration
- `provider.tf` - AWS provider configuration
- `terraform.tfvars` - Production-specific variables

## Usage

```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## Environment-Specific Settings

- Uses least-privilege IAM role for production environment
- State stored in production-specific S3 prefix
- Resource tagging with environment=prod
- Manual approval REQUIRED for all deployments (default behavior)

## Deployment Process

1. Changes are deployed via GitHub Actions
2. Pull requests trigger terraform plan
3. Merge to main branch triggers terraform apply
4. **Manual approval required** before apply
5. Multiple approvers may be required based on configuration

## Security Considerations

- Strictest IAM permissions (least privilege)
- Enhanced monitoring and logging
- All changes require manual review and approval
- State backups retained for 1 year
- Comprehensive audit trail enabled

## State Management

- Remote state stored in S3 with encryption
- State locking via DynamoDB
- Versioning enabled for state recovery
- Extended backup retention (365 days)
- Additional state monitoring and alerts