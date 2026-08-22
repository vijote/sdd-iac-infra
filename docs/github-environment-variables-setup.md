# GitHub Environment Variables Setup Guide

This guide explains how to configure the required environment variables for the GitHub Actions workflows with role chaining.

## Required Environment Variables

### AWS Bootstrap Role
- **Name**: `AWS_BOOTSTRAP_ROLE`
- **Type**: Repository Variable (not secret)
- **Description**: The ARN of the bootstrap IAM role for OIDC authentication
- **Value**: `arn:aws:iam::123456789012:role/github-oidc-bootstrap-role` (replace with your actual role ARN)

### AWS Terraform Role
- **Name**: `AWS_TERRAFORM_ROLE`
- **Type**: Repository Variable (not secret)
- **Description**: The ARN of the target IAM role for Terraform operations
- **Value**: `arn:aws:iam::123456789012:role/terraform-execution-role` (replace with your actual role ARN)

### State Bucket Name
- **Name**: `STATE_BUCKET_NAME`
- **Type**: Repository Variable (not secret)
- **Description**: The name of your manually created S3 bucket for Terraform state
- **Value**: `your-terraform-state-bucket-name` (replace with your actual bucket name)

## How to Add Environment Variables

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **Variables** tab (not Secrets)
4. Click **New repository variable**
5. Enter the name and value
6. Click **Add variable**

## Why Variables Instead of Secrets?

- **IAM Role ARNs** are not sensitive information - they're discoverable through IAM policies
- Using variables makes it easier to configure and view
- OIDC authentication eliminates the need for sensitive AWS credentials
- Role chaining provides better security separation between authentication and execution

## Role Chaining Architecture

The workflows use a two-step authentication process:

1. **Bootstrap Role**: Authenticates via GitHub OIDC and has permission to assume the terraform role
2. **Terraform Role**: Has the actual permissions needed for Terraform operations

This pattern provides:
- Better security separation
- Easier role management
- Clear audit trails
- Least privilege for each role

## Security Notes

- The workflows use OpenID Connect (OIDC) authentication
- No static AWS credentials are stored in GitHub
- Role chaining provides security separation between authentication and execution
- The IAM roles should provide least-privilege access for their specific purposes

## Troubleshooting

### Common Issues

1. **"Access Denied" errors**
   - Verify both role ARNs are correct
   - Check that bootstrap role has permission to assume terraform role
   - Ensure OIDC trust relationship is configured for bootstrap role
   - Verify terraform role has necessary permissions for your resources

2. **"Variable not found" errors**
   - Ensure variables are added under **Variables** tab, not **Secrets**
   - Check variable names exactly match `AWS_BOOTSTRAP_ROLE` and `AWS_TERRAFORM_ROLE`

3. **"Role chaining failed" errors**
   - Ensure `role-chaining: true` is set in the second credential configuration
   - Verify the bootstrap role has `sts:AssumeRole` permission for the terraform role

### Validation Commands

```bash
# Test AWS credentials
aws sts get-caller-identity

# Verify OIDC provider
aws iam list-open-id-connect-providers
```

## Next Steps

After setting up the environment variables:
1. The workflows will automatically use OIDC authentication with role chaining
2. No manual approvals required (simplified for solo development)
3. Only dev and prod environments available (staging removed)
4. Deployments will run automatically on push to main branch
5. Role chaining provides better security separation for your infrastructure