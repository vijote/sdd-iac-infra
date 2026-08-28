# Data source for manually created S3 bucket for Terraform State
data "aws_s3_bucket" "terraform_state" {
  bucket = var.aws_state_bucket_name
}