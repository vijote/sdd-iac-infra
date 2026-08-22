# Manual State Bucket Setup Guide

This guide explains how to manually create the S3 bucket for Terraform state storage.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Your target AWS region

## Create S3 Bucket

### For us-east-1 Region

```bash
# Replace with your preferred bucket name
BUCKET_NAME="your-terraform-state-bucket-name"
AWS_REGION="us-east-1"

# Create the bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $AWS_REGION
```

### For Other Regions

```bash
# Replace with your preferred bucket name and region
BUCKET_NAME="your-terraform-state-bucket-name"
AWS_REGION="us-west-2"

# Create the bucket (requires LocationConstraint for non-us-east-1)
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $AWS_REGION \
  --create-bucket-configuration LocationConstraint=$AWS_REGION
```

## Configure Bucket Security

```bash
# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

## (Optional) Create DynamoDB Table for State Locking

If you want state locking (recommended for team collaboration):

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --region $AWS_REGION
```

## Add to GitHub Variables

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **Variables** tab
4. Add `STATE_BUCKET_NAME` with your bucket name

## Verify Setup

```bash
# Verify bucket exists
aws s3 ls | grep $BUCKET_NAME

# Verify versioning
aws s3api get-bucket-versioning --bucket $BUCKET_NAME

# Verify encryption
aws s3api get-bucket-encryption --bucket $BUCKET_NAME
```

## Next Steps

1. Add the bucket name to GitHub variables as `STATE_BUCKET_NAME`
2. The workflows will now use this bucket for Terraform state
3. Your state is not exposed in the codebase