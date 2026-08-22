# AWS Provider Configuration
provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project = "sdd-infra"
    }
  }
}