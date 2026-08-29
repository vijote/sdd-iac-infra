# Quickstart Guide: S3 State Unlock

**Date**: 2025-01-29  
**Feature**: S3 State Unlock

## Prerequisites

1. **Repository Access**
   - Must have write access to the repository
   - GitHub Actions must be enabled

2. **AWS Credentials**
   - AWS access key with S3 permissions
   - AWS secret key
   - Store these as repository secrets:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
     - Optional: `AWS_DEFAULT_REGION`

3. **IAM Permissions**
   Ensure your AWS credentials have these minimum permissions:
   ```
   s3:DeleteObject on arn:aws:s3:::your-bucket/*.tflock
   s3:GetObject on arn:aws:s3:::your-bucket/*.tflock
   s3:HeadObject on arn:aws:s3:::your-bucket/*.tflock
   ```

## Usage

### 1. Trigger the Workflow

1. Navigate to your repository on GitHub
2. Go to the "Actions" tab
3. Select "Unlock Terraform State" workflow
4. Click "Run workflow"
5. Fill in the required inputs:
   - **Bucket**: The S3 bucket name containing your Terraform state
   - **State Key**: The path to your Terraform state file (without .tflock)
6. Click "Run workflow"

### 2. Monitor Execution

- The workflow will show real-time logs
- Check the "Summary" section for the final result
- Workflow typically completes in under 30 seconds

### 3. Verify Result

**Success scenarios:**
- "Lock removed successfully" - A stale lock was found and removed
- "No lock found" - State was already unlocked

**Failure scenarios:**
- Check the error message in the workflow logs
- Common issues: incorrect credentials, insufficient permissions, wrong bucket name

## Validation Scenarios

### Scenario 1: Normal Lock Removal
1. Start a Terraform apply and cancel it mid-execution
2. Run the unlock workflow
3. Verify: Lock is removed, new Terraform operations can proceed

### Scenario 2: No Lock Present
1. Run the unlock workflow on an unlocked state
2. Verify: Workflow reports "No lock found" (success)

### Scenario 3: Invalid Bucket
1. Run workflow with non-existent bucket name
2. Verify: Workflow fails with clear error message

## Troubleshooting

### Common Issues

**"AWS authentication failed"**
- Check that AWS secrets are correctly configured
- Verify credentials are valid and not expired

**"Insufficient permissions"**
- Ensure IAM role has s3:DeleteObject permission
- Check bucket policy allows the operations

**"S3 bucket not found"**
- Verify bucket name spelling
- Check bucket exists in correct region

### Debug Information

The workflow provides:
- Lock metadata when a lock is found
- Detailed error messages for failures
- Clear success/failure status

## Integration with Existing Workflows

This unlock workflow is designed to be:
- Non-disruptive to existing Terraform workflows
- Safe to run anytime (checks for lock existence first)
- Complementary to your existing CI/CD pipeline

## Next Steps

After successful unlock:
1. Re-run your cancelled Terraform workflow
2. Verify normal operation resumes
3. Consider reviewing why the original workflow was cancelled