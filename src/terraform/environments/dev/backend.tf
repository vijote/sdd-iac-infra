terraform {
  backend "s3" {
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

    # State file settings
    acl = "bucket-owner-full-control"
  }
}