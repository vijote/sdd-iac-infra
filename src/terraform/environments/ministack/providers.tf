# MiniStack Provider Configuration
provider "aws" {
  region = "us-east-1"
  
  # MiniStack/LocalStack configuration
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
  
  # MiniStack endpoints
  endpoints {
    s3       = "http://localhost:4566"
    sqs      = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    lambda   = "http://localhost:4566"
    ec2      = "http://localhost:4566"
    iam      = "http://localhost:4566"
  }
  
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project = "sdd-infra"
    }
  }
}