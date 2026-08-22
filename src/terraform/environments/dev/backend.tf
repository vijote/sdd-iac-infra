terraform {
  backend "s3" {
    bucket         = "terraform-state-dev-xxxxxxxx" # Will be updated after state bucket creation
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-dev" # Will be updated after lock table creation
    
    # Locking configuration
    lock_table = "terraform-locks-dev"
    
    # State file settings
    acl = "bucket-owner-full-control"
  }
}