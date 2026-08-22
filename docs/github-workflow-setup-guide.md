# GitHub Workflow Setup Guide

This guide provides step-by-step instructions for configuring GitHub Actions workflows for the Secure Deployment Foundation implementation.

## Overview

The GitHub Actions workflows use OpenID Connect (OIDC) authentication to AWS, eliminating the need for static AWS credentials. However, there's a bootstrap requirement: IAM roles and S3 buckets must be created before the workflows can run.

## Prerequisites

- AWS CLI configured with admin credentials
- GitHub repository with appropriate permissions
- Terraform installed locally

## Required GitHub Secrets

Navigate to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** and add the following:

### 1. AWS Account ID (Required)
- **Name**: `AWS_ACCOUNT_ID`
- **Description**: Your 12-digit AWS account ID
- **How to get**: 
  ```bash
  aws sts get-caller-identity --query Account --output text
  ```
- **Value**: `123456789012` (replace with your actual account ID)

### 2. GitHub Token (Optional but recommended)
- **Name**: `GH_TOKEN`
- **Description**: Personal access token for GitHub API operations
- **Required for**: PR commenting, workflow status updates
- **Permissions**: `repo`, `workflow:read`
- **How to create**:
  1. Go to GitHub → Settings → Developer settings → Personal access tokens
  2. Generate new token with `repo` and `workflow:read` permissions

## Environment Variables (Optional)

Add these under **Variables** section (not secrets):

### 1. Staging Approval Control
- **Name**: `STAGING_APPROVAL_REQUIRED`
- **Value**: `false` (default)
- **Description**: Set to `true` to require manual approval for staging deployments

### 2. Production Approval Control
- **Name**: `PROD_APPROVAL_REQUIRED`
- **Value**: `true` (recommended)
- **Description**: Set to `true` to require manual approval for production deployments

## Bootstrap Process

### Phase 1: Initial Infrastructure Setup

Since the workflows require IAM roles and S3 buckets to exist, you must create them manually first:

#### 1. Create S3 Bucket for Terraform State
```bash
# Replace with your bucket name
BUCKET_NAME="terraform-state-sdd-infra-dev"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $AWS_REGION

aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

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
```

#### 2. Create IAM Roles for OIDC Authentication

First, get your GitHub OIDC provider:
```bash
# Get GitHub OIDC provider thumbprint
curl https://token.actions.githubusercontent.com/.well-known/openid-configuration | jq -r '.jwks_uri' | curl | jq -r '.keys[0].x5c[0]' | openssl x509 -noout -fingerprint -sha1 | cut -d'=' -f2 | tr -d ':'
```

Create the IAM role trust policy:
```bash
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:vijote/sdd-iac-infra:ref:refs/heads/*"
        }
      }
    }
  ]
}
EOF
```

Create the IAM role:
```bash
aws iam create-role \
  --role-name terraform-dev-role \
  --assume-role-policy-document file://trust-policy.json \
  --description "Terraform deployment role for dev environment"

# Attach appropriate policies (example for dev - least privilege)
aws iam attach-role-policy \
  --role-name terraform-dev-role \
  --policy-arn arn:aws:iam::aws:policy/AdminAccess  # Start with this, then scope down

# Repeat for staging and prod roles
aws iam create-role \
  --role-name terraform-staging-role \
  --assume-role-policy-document file://trust-policy.json \
  --description "Terraform deployment role for staging environment"

aws iam attach-role-policy \
  --role-name terraform-staging-role \
  --policy-arn arn:aws:iam::aws:policy/AdminAccess

aws iam create-role \
  --role-name terraform-prod-role \
  --assume-role-policy-document file://trust-policy.json \
  --description "Terraform deployment role for production environment"

aws iam attach-role-policy \
  --role-name terraform-prod-role \
  --policy-arn arn:aws:iam::aws:policy/AdminAccess
```

#### 3. Update Terraform Backend Configuration

Update `src/terraform/environments/dev/backend.tf` with your bucket name:
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-sdd-infra-dev"  # Your bucket name
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
    acl            = "bucket-owner-full-control"
  }
}
```

### Phase 2: Test Local Terraform

```bash
cd src/terraform/environments/dev/
terraform init
terraform plan
terraform apply  # This will create the VPC networking foundation
```

### Phase 3: Test GitHub Workflow

1. Commit and push your changes
2. Create a pull request
3. The workflow should now run successfully with OIDC authentication

## Workflow Permissions

Ensure your repository has the correct Actions permissions:

1. Go to **Settings** → **Actions** → **General**
2. Under "Workflow permissions", select:
   - **Read and write permissions**
   - **Allow GitHub Actions to create and approve pull requests**
   - **Allow GitHub Actions to run approve pull requests**

## Troubleshooting

### Common Issues

1. **"Access Denied" errors**
   - Verify `AWS_ACCOUNT_ID` is correct
   - Check IAM role permissions
   - Ensure OIDC trust relationship is configured correctly

2. **"Repository not found" errors**
   - Verify repository format in trust policy: `owner/repo`
   - Check repository permissions

3. **"Workflow permission" errors**
   - Ensure workflows have `id-token: write` permission
   - Check repository settings for Actions permissions

4. **"S3 bucket not found" errors**
   - Verify bucket name in backend configuration
   - Check bucket exists in correct region

### Validation Commands

```bash
# Test AWS credentials
aws sts get-caller-identity

# Test GitHub token
gh auth status

# Verify OIDC provider
aws iam list-open-id-connect-providers

# Verify IAM roles
aws iam get-role --role-name terraform-dev-role
```

## Security Best Practices

1. **Principle of Least Privilege**: Scope down IAM role permissions from `AdminAccess` to specific resources
2. **Regular Rotation**: Rotate secrets and review permissions regularly
3. **Audit Logging**: Enable CloudTrail for all AWS API calls
4. **Environment Isolation**: Use separate IAM roles for each environment

## Next Steps

After initial setup:

1. **Scope Down IAM Permissions**: Replace `AdminAccess` with specific policies for each environment
2. **Add State Locking**: Configure DynamoDB table for Terraform state locking
3. **Add Monitoring**: Set up CloudWatch alerts for deployment activities
4. **Add Approval Workflows**: Configure manual approval for staging and production

## Implementation Notes for Humans

This section captures the manual steps that cannot be automated and require human intervention:

### AWS Console Actions Required
- [ ] Create S3 bucket for Terraform state
- [ ] Configure bucket versioning and encryption
- [ ] Create IAM roles for each environment
- [ ] Configure OIDC trust relationship
- [ ] Set up appropriate IAM policies

### GitHub Actions Configuration Required
- [ ] Add AWS_ACCOUNT_ID secret
- [ ] Add GH_TOKEN secret (optional)
- [ ] Configure environment variables
- [ ] Set workflow permissions
- [ ] Enable Actions for repository

### One-Time Bootstrap Steps
- [ ] Run initial Terraform apply locally
- [ ] Verify OIDC authentication works
- [ ] Test pull request workflow
- [ ] Verify deployment to dev environment

### Ongoing Maintenance
- [ ] Review and rotate secrets quarterly
- [ ] Audit IAM permissions monthly
- [ ] Monitor workflow execution logs
- [ ] Update trust policies if repository changes

---

**Note**: This setup is a one-time bootstrap process. Once complete, all subsequent deployments should work automatically through the GitHub Actions workflows.