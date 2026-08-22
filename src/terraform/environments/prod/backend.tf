terraform {
  backend "s3" {
    bucket         = "terraform-state-prod-xxxxxxxx" # Will be updated after state bucket creation
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-prod" # Will be updated after lock table creation
    
    # Locking configuration
    lock_table = "terraform-locks-prod"
    
    # State file settings
    acl = "bucket-owner-full-control"
  }
}