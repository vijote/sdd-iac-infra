# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.state_bucket_prefix}-${var.environment}-${random_suffix.this.result}"

  tags = {
    Name        = "${var.state_bucket_prefix}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "terraform-state"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.lock_table_prefix}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.lock_table_prefix}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "terraform-locks"
  }
}

# Random suffix to avoid naming conflicts
resource "random_suffix" "this" {
  length = 8
}