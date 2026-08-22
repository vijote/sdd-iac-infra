terraform {
  backend "s3" {
    bucket         = "terraform-state-dev-xxxxxxxx" # Will be updated after state bucket creation
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
    
    # State file settings
    acl = "bucket-owner-full-control"
  }
}