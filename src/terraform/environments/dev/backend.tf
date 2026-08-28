terraform {
  backend "s3" {
    bucket       = var.aws_state_bucket_name
    key          = "application-deployment/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

    # State file settings
    acl = "bucket-owner-full-control"
  }
}