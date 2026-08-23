# State Management Module

This module references manually created S3 buckets for remote Terraform state storage with native S3 locking.

## Features

- References manually created S3 bucket with versioning and encryption
- Uses native S3 object locking
- Environment isolation through naming conventions
- No resource creation - only data source references

## Prerequisites

Before using this module, ensure the following resources exist in your AWS account:
- S3 bucket: `terraform-state-{environment}` (e.g., `terraform-state-dev`)

The S3 bucket must have:
- Versioning enabled
- Server-side encryption configured (SSE-S3 or SSE-KMS)
- Public access blocked
- Object Lock enabled for state locking
- Appropriate IAM policies for state access

## Usage

```hcl
module "state" {
  source = "./modules/state"
  
  environment         = "dev"
  state_bucket_prefix = "terraform-state"
  aws_region         = "us-east-1"
}
```

## Terraform Backend Configuration

Configure your Terraform backend to use this S3 bucket with native locking:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-dev"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    lock_table     = false  # Use native S3 locking
  }
}
```

## Outputs

- `state_bucket_name` - Name of the S3 bucket for state storage
- `state_bucket_arn` - ARN of the S3 bucket for state storage

## Notes

- This module does NOT create S3 buckets
- Resources must follow the naming convention: `{prefix}-{environment}`
- Manual resource creation must include proper security configurations
- Native S3 locking provides state locking
- Ensure Object Lock is enabled on the S3 bucket for proper state locking