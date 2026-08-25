terraform {
  backend "s3" {
    bucket       = "sdd-infra-terraform-state"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

    # State file settings
    acl = "bucket-owner-full-control"
  }
}