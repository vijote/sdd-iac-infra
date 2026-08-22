# Troubleshooting Guide

This guide covers common issues and their solutions for the Secure Deployment Foundation.

## GitHub Actions Issues

### OIDC Authentication Failures

**Error**: "AccessDenied: Token is not from a valid provider for this identity provider"

**Solutions**:
1. Verify AWS_ACCOUNT_ID secret is correct
2. Check that OIDC provider is created in AWS
3. Ensure repository name matches the trust relationship
4. Verify GitHub Actions permissions include `id-token: write`

**Verification Commands**:
```bash
# Check AWS account ID
aws sts get-caller-identity --query Account --output text

# List OIDC providers
aws iam list-open-id-connect-providers
```

### Workflow Permission Errors

**Error**: "Permission denied" or "Resource not accessible"

**Solutions**:
1. Check repository Actions permissions
2. Verify workflow permissions in YAML files
3. Ensure secrets are properly configured

**Required Permissions**:
```yaml
permissions:
  id-token: write          # Required for OIDC
  contents: read          # Required for checkout
  pull-requests: write    # Required for PR comments
  actions: read           # Required for workflow status
```

### Terraform Plan/Apply Failures

**Error**: "Terraform validation failed" or "Plan execution failed"

**Solutions**:
1. Check Terraform version compatibility
2. Verify backend configuration
3. Ensure IAM role has sufficient permissions
4. Check state file accessibility

## IAM Role Issues

### Least Privilege Violations

**Error**: "AccessDenied" for specific AWS actions

**Solutions**:
1. Review IAM policy permissions
2. Add missing actions to terraform-permissions policy
3. Ensure resource ARNs are correctly scoped
4. Check condition statements in policies

**Common Missing Permissions**:
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:CreateVpc",
    "ec2:DeleteVpc",
    "s3:CreateBucket",
    "dynamodb:CreateTable"
  ],
  "Resource": "*"
}
```

### Role Trust Relationship Issues

**Error**: "AssumeRole denied" or "Invalid trust relationship"

**Solutions**:
1. Verify OIDC provider URL is correct
2. Check thumbprint matches GitHub's current thumbprint
3. Ensure condition statements are properly formatted
4. Validate repository name format

## State Management Issues

### State Lock Failures

**Error**: "Error acquiring state lock" or "Lock already held"

**Solutions**:
1. Check for ongoing Terraform operations
2. Manually unlock state if necessary
3. Verify DynamoDB table accessibility
4. Check IAM permissions for DynamoDB

**Force Unlock (Last Resort)**:
```bash
terraform force-unlock LOCK_ID
```

### State File Corruption

**Error**: "State file is corrupted" or "Invalid state format"

**Solutions**:
1. Restore from previous version (if versioning enabled)
2. Check S3 bucket integrity
3. Verify encryption settings
4. Use state backup if available

**State Recovery**:
```bash
# List previous versions
aws s3api list-object-versions --bucket your-state-bucket --prefix dev/terraform.tfstate

# Restore previous version
aws s3api get-object --bucket your-state-bucket --key dev/terraform.tfstate --version-id VERSION_ID terraform.tfstate
```

## Environment Configuration Issues

### Backend Configuration Errors

**Error**: "Failed to configure backend" or "Backend initialization failed"

**Solutions**:
1. Verify S3 bucket exists and is accessible
2. Check DynamoDB table exists
3. Ensure bucket policies allow access
4. Validate region configuration

**Backend Validation**:
```bash
# Test S3 access
aws s3 ls s3://your-state-bucket

# Test DynamoDB access
aws dynamodb describe-table --table-name your-lock-table
```

### Provider Configuration Issues

**Error**: "Provider configuration invalid" or "Authentication failed"

**Solutions**:
1. Check AWS region configuration
2. Verify provider version constraints
3. Ensure credentials are properly configured
4. Validate variable values

## Performance Issues

### Slow Terraform Operations

**Symptoms**: Plans or applies taking excessive time

**Solutions**:
1. Check AWS API rate limits
2. Optimize Terraform configuration
3. Use parallel execution where possible
4. Review resource dependencies

**Performance Monitoring**:
```bash
# Enable detailed logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Run with timing
terraform apply -timing
```

### High AWS Costs

**Symptoms**: Unexpected charges or cost overruns

**Solutions**:
1. Review resource tags for cost allocation
2. Check for unused resources
3. Monitor S3 storage costs
4. Review DynamoDB usage patterns

**Cost Monitoring**:
```bash
# Check AWS cost and usage
aws ce get-cost-and-usage --time-period Start=2023-01-01,End=2023-01-31 --granularity MONTHLY

# List S3 bucket sizes
aws s3 ls --summarize --human-readable --recursive s3://your-state-bucket
```

## Security Issues

### Unauthorized Access

**Symptoms**: Unexpected resource modifications

**Solutions**:
1. Review CloudTrail logs
2. Check IAM role usage
3. Validate OIDC trust relationships
4. Review GitHub Actions access logs

**Security Audit**:
```bash
# Check recent CloudTrail events
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity

# List IAM role usage
aws iam get-role --role-name terraform-dev-role
```

### Credential Exposure

**Symptoms**: Credentials found in logs or repositories

**Solutions**:
1. Rotate exposed credentials immediately
2. Review repository secrets
3. Check for hardcoded credentials
4. Enable enhanced monitoring

## Testing Issues

### Test Failures

**Error**: Integration tests failing

**Solutions**:
1. Check test environment setup
2. Verify test credentials
3. Review test configuration
4. Check resource dependencies

**Test Debugging**:
```bash
# Run tests with verbose output
go test -v ./tests/...

# Run specific test
go test -v -run TestOIDCProvider ./tests/ci_cd/
```

### Mock/Stub Issues

**Error**: Mock objects not working correctly

**Solutions**:
1. Review mock configurations
2. Check test data setup
3. Verify interface implementations
4. Update mock expectations

## Getting Help

### Log Collection

**GitHub Actions Logs**:
1. Go to repository Actions tab
2. Select failed workflow run
3. Download logs for analysis
4. Check individual job outputs

**AWS CloudTrail Logs**:
```bash
# Create CloudTrail for debugging
aws cloudtrail create-trail --name sdd-infra-debug --s3-bucket-name your-log-bucket

# Query CloudTrail events
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=terraform-dev-role
```

### Support Channels

1. **Documentation**: Check inline code comments and README files
2. **GitHub Issues**: Create detailed issue with error logs
3. **Team Communication**: Use designated channels for urgent issues
4. **AWS Support**: Contact AWS for service-specific issues

### Emergency Procedures

**Production Deployment Failure**:
1. Stop all automated deployments
2. Review recent changes
3. Rollback if necessary
4. Communicate with stakeholders

**Security Incident**:
1. Immediately rotate all credentials
2. Review audit logs
3. Document findings
4. Implement additional safeguards

## Prevention

### Best Practices

1. **Regular Testing**: Run tests before deployments
2. **Code Reviews**: Review all changes carefully
3. **Monitoring**: Set up alerts for unusual activity
4. **Documentation**: Keep documentation up to date

### Monitoring Setup

```bash
# Create CloudWatch alarms
aws cloudwatch put-metric-alarm --alarm-name "TerraformFailures" --metric-name Failures --namespace "Terraform" --statistic Sum --period 300 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold

# Create SNS topic for notifications
aws sns create-topic --name sdd-infra-alerts
```

---

**Last Updated**: 2025-08-22  
**Version**: 1.0  
**Maintainer**: SDD Infrastructure Team