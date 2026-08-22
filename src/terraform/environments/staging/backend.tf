terraform {
  backend "s3" {
    bucket         = "terraform-state-staging-xxxxxxxx" # Will be updated after state bucket creation
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-staging" # Will be updated after lock table creation
    
    # Locking configuration
    lock_table = "terraform-locks-staging"
    
    # State file settings
    acl = "bucket-owner-full-control"
  }
}