# Destroy Pipeline Troubleshooting Guide

**Last Updated**: 2025-08-25  
**Pipeline**: Destroy Dev Environment

## Common Issues and Solutions

### 1. Input Validation Errors

#### "Only 'dev' environment is supported"
**Cause**: Selected environment other than "dev"  
**Solution**: 
- Ensure you select "dev" from the environment dropdown
- The pipeline is restricted to dev environment only for safety

#### "Confirmation must be exactly 'destroy'"
**Cause**: Confirmation text doesn't match exactly  
**Solution**:
- Type `destroy` (lowercase, no quotes)
- No extra spaces or characters
- Must match exactly

### 2. Permission Issues

#### "AccessDenied" or "permission denied"
**Cause**: IAM role lacks required permissions  
**Solution**:
1. Check OIDC role configuration:
   ```bash
   aws sts get-caller-identity
   ```
2. Verify role has these permissions:
   - `ec2:*`
   - `elasticloadbalancing:*`
   - `iam:PassRole`
   - `kms:Decrypt`
   - `kms:DescribeKey`
   - `s3:GetObject`
   - `s3:PutObject`
   - `s3:DeleteObject`

3. Contact repository maintainers to update IAM role if needed

#### "Unable to locate credentials"
**Cause**: AWS credentials not configured  
**Solution**:
- Verify OIDC integration is properly configured
- Check GitHub Actions secrets: `AWS_ACCOUNT_ID`
- Ensure role trust relationship includes the repository

### 3. Terraform Issues

#### "State lock" errors
**Cause**: Another Terraform operation is in progress  
**Solution**:
1. Check for other running workflows
2. Wait for other operations to complete
3. If lock is stuck, contact maintainers for force-unlock

#### "Backend configuration changed"
**Cause**: Terraform backend configuration mismatch  
**Solution**:
1. Verify backend.tf configuration
2. Check S3 bucket exists and is accessible
3. Ensure DynamoDB table (if used) exists

#### "Resource not found" during plan
**Cause**: Resources already destroyed or missing  
**Solution**:
- This is normal if environment already partially destroyed
- Continue with destruction to clean up remaining resources

### 4. AWS Resource Issues

#### "DependencyViolation" when destroying security groups
**Cause**: Security group still has dependencies  
**Solution**:
1. Check for attached ENIs, instances, or other resources
2. Manual cleanup may be required:
   ```bash
   aws ec2 describe-network-interfaces --filters Name=group-id,Values=sg-xxxxxxxx
   ```
3. Retry the destruction pipeline

#### "InvalidVpcID.NotFound" errors
**Cause**: VPC already deleted but referenced in state  
**Solution**:
1. Run `terraform state rm` for missing resources
2. Or use `terraform apply` to refresh state
3. Retry destruction

#### "VolumeInUse" for EBS volumes
**Cause**: EBS volume still attached to instance  
**Solution**:
1. Force detach if instance is being terminated:
   ```bash
   aws ec2 detach-volume --volume-id vol-xxxxxxxx --force
   ```
2. Retry destruction

### 5. GitHub Actions Issues

#### "Workflow timeout"
**Cause**: Pipeline exceeded 10-hour timeout  
**Solution**:
1. Check for large numbers of resources
2. Verify AWS rate limits not exceeded
3. Consider running in smaller batches

#### "Artifact upload failed"
**Cause**: Artifact too large or upload error  
**Solution**:
1. Check artifact size limit (GitHub limit: 2GB)
2. Verify network connectivity
3. Artifacts are optional - destruction may have succeeded

#### "Runner out of memory"
**Cause**: Large Terraform state or plan  
**Solution**:
1. This is rare for typical dev environments
2. Contact maintainers if issue persists

## Debugging Steps

### 1. Check Workflow Logs
1. Go to Actions tab
2. Click on the workflow run
3. Review each step's logs
4. Look for error messages and warnings

### 2. Examine Generated Artifacts
1. Download artifacts from the workflow run
2. Check `destruction_report.md` for status
3. Review `terraform-state-*` for state backup
4. Examine inventory files for resource list

### 3. Manual AWS Console Check
1. Log into AWS Console
2. Check EC2 instances
3. Check VPC resources
4. Verify S3 bucket contents
5. Look for CloudTrail logs

### 4. Local Debugging
Clone the repository and run scripts locally:
```bash
# Check permissions
./scripts/validate-permissions.sh dev

# Generate inventory
./scripts/generate-inventory.sh dev

# Dry run destruction
./scripts/destroy-dev.sh dev destroy true
```

## Recovery Procedures

### If Destruction Fails Midway

1. **Check What Was Destroyed**:
   - Review workflow logs
   - Check AWS console
   - Download and review artifacts

2. **Complete Remaining Cleanup**:
   - Manually destroy remaining resources
   - Use AWS Console for stubborn resources
   - Document what was manually cleaned

3. **Update Terraform State**:
   ```bash
   cd src/terraform/environments/dev
   terraform refresh
   terraform state rm <resource>  # For destroyed resources
   ```

### If You Need to Recreate Environment

1. **Restore State Backup**:
   - Download state backup artifact
   - Extract `terraform.tfstate.backup`
   - Copy to `src/terraform/environments/dev/`

2. **Run Deployment**:
   - Use the deployment pipeline
   - Or run `terraform apply` manually

3. **Verify Services**:
   - Check all resources are created
   - Test applications
   - Verify connectivity

## Prevention Tips

### Before Destruction
1. **Notify Team**: Let everyone know you're destroying dev
2. **Check for Active Work**: Ensure no one is using the environment
3. **Backup Important Data**: Save any needed data from instances
4. **Document Current State**: Note what's currently deployed

### After Destruction
1. **Verify Costs**: Check billing dashboard
2. **Look for Orphans**: Search for remaining resources
3. **Update Documentation**: Note destruction completion
4. **Archive Artifacts**: Save reports for audit

## Getting Help

### Create an Issue
Include this information:
- Workflow run ID and URL
- Error messages (full text)
- Steps you took
- Expected vs actual behavior
- Screenshots if helpful

### Emergency Contacts
- Infrastructure team
- Repository maintainers
- AWS administrator (if applicable)

### Useful Commands
```bash
# Check current AWS identity
aws sts get-caller-identity

# List all EC2 instances with dev tag
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"

# List all VPCs with dev tag
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"

# Check S3 buckets
aws s3 ls

# Check CloudTrail for recent activity
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances
```

## Performance Considerations

- **Typical destruction time**: 5-10 minutes
- **Large environments**: May take up to 30 minutes
- **Rate limits**: AWS may throttle bulk operations
- **Timeout**: Workflow fails after 10 hours

## Security Notes

- All actions are logged in CloudTrail
- State backups contain sensitive information
- IAM role follows least privilege principle
- No credentials are stored in GitHub