# Repository Secrets Configuration Guide

This guide explains how to configure the required repository secrets for the Secure Deployment Foundation.

## Required Secrets

### AWS Account ID
- **Name**: `AWS_ACCOUNT_ID`
- **Description**: Your 12-digit AWS account ID
- **How to get**: Run `aws sts get-caller-identity --query Account --output text` or check AWS Management Console

### GitHub Token (Optional)
- **Name**: `GH_TOKEN` 
- **Description**: Personal access token for GitHub API operations
- **Required for**: PR commenting, workflow status updates
- **Permissions**: `repo`, `workflow:read`

## Environment-Specific Secrets

### Development Environment
No additional secrets required - uses OIDC authentication.

### Staging Environment
- **Name**: `STAGING_APPROVAL_REQUIRED`
- **Description**: Set to `true` to require manual approval for staging deployments
- **Default**: `false`

### Production Environment
- **Name**: `PROD_APPROVAL_REQUIRED` 
- **Description**: Set to `true` to require manual approval for production deployments
- **Default**: `true` (recommended)

## How to Add Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter the name and value
5. Click **Add secret**

## Security Notes

- Never commit secrets to your repository
- Use environment-specific secrets when possible
- Rotate secrets regularly
- Use least-privilege access patterns

## OIDC Configuration

The workflows use OpenID Connect (OIDC) authentication, which eliminates the need for static AWS credentials. The OIDC trust relationship is automatically configured by the IAM module.

## Troubleshooting

### Common Issues

1. **"Access Denied" errors**
   - Verify AWS_ACCOUNT_ID is correct
   - Check IAM role permissions
   - Ensure OIDC trust relationship is configured

2. **"Repository not found" errors**
   - Verify github_repository format: `owner/repo`
   - Check repository permissions

3. **"Workflow permission" errors**
   - Ensure workflows have `id-token: write` permission
   - Check repository settings for Actions permissions

### Validation Commands

```bash
# Test AWS credentials
aws sts get-caller-identity

# Test GitHub token
gh auth status

# Verify OIDC provider
aws iam list-open-id-connect-providers
```