# IAM Module

This module attaches policies to manually created IAM roles for Terraform operations with least-privilege access.

## Features

- References manually created OIDC roles via data sources
- Environment-specific policies (dev, staging, prod)
- Least-privilege policies following principle of least privilege
- CloudWatch logging for audit trail

## Prerequisites

Before using this module, ensure the following IAM roles exist in your AWS account:
- `terraform-dev-role`
- `terraform-staging-role` 
- `terraform-prod-role`

These roles must be manually created with proper OIDC trust relationships for GitHub Actions.

## Usage

```hcl
module "iam" {
  source = "./modules/iam"
  
  environment     = "dev"
  aws_account_id = "123456789012"
  aws_region     = "us-east-1"
}
```

## Outputs

- `terraform_role_arn` - ARN of the Terraform execution role
- `terraform_role_name` - Name of the referenced IAM role

## Notes

- This module does NOT create IAM roles - it only attaches policies
- Roles must follow the naming convention: `terraform-{environment}-role`
- Manual role creation must include proper OIDC trust relationships