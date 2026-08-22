# State Management Module

This module configures remote Terraform state storage with S3 and DynamoDB for locking.

## Features

- S3 bucket with versioning and encryption
- DynamoDB table for state locking
- Environment isolation
- State backup and retention policies

## Usage

```hcl
module "state" {
  source = "./modules/state"
  
  environment = "dev"
  state_bucket = "my-terraform-state"
  lock_table = "terraform-locks"
}
```

## Outputs

- `state_bucket_name` - Name of the S3 bucket for state storage
- `lock_table_name` - Name of the DynamoDB table for state locking