# IAM Module

This module creates IAM roles and policies for Terraform operations with least-privilege access.

## Features

- OIDC trust relationships for GitHub Actions
- Environment-specific roles (dev, staging, prod)
- Least-privilege policies following principle of least privilege
- Session tagging and audit logging

## Usage

```hcl
module "iam" {
  source = "./modules/iam"
  
  environment = "dev"
  github_repo = "your-org/your-repo"
}
```

## Outputs

- `terraform_role_arn` - ARN of the Terraform execution role
- `role_name` - Name of the created IAM role