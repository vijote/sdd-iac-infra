# GitHub Workflow Contract: S3 State Unlock

**Date**: 2025-01-29  
**Feature**: S3 State Unlock

## Workflow Interface

### File Location
- Path: `.github/workflows/unlock-terraform-state.yml`
- Name: "Unlock Terraform State"

### Trigger
```yaml
on:
  workflow_dispatch:
    inputs:
      bucket:
        description: 'S3 bucket containing Terraform state'
        required: true
        type: string
      state_key:
        description: 'Terraform state file key (without .tflock extension)'
        required: true
        type: string
```

### Environment Variables Required
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_DEFAULT_REGION`: AWS region (optional, defaults to us-east-1)

### Permissions
```yaml
permissions:
  contents: read  # Required for checkout
```

## Expected Behavior

### Success Scenarios
1. **Lock exists and is removed**
   - Returns: "Lock removed successfully"
   - Includes: Lock metadata (who, when, operation)

2. **No lock found**
   - Returns: "No lock found - state is already unlocked"
   - Status: Success

### Failure Scenarios
1. **Invalid credentials**
   - Returns: "AWS authentication failed"
   - Status: Failure

2. **Insufficient permissions**
   - Returns: "Insufficient permissions to delete lock object"
   - Status: Failure

3. **Bucket not found**
   - Returns: "S3 bucket not found"
   - Status: Failure

4. **Network error**
   - Returns: "Failed to communicate with AWS"
   - Status: Failure

## Output Format

### GitHub Actions Summary
- Always displays a summary message
- Shows lock details when lock was found
- Provides clear error messages for failures

### Job Outputs
```yaml
outputs:
  result:
    description: 'Result message'
    value: ${{ steps.unlock.outputs.result }}
  lock_found:
    description: 'Whether a lock was found'
    value: ${{ steps.unlock.outputs.lock_found }}
```

## Implementation Constraints

### Must Use
- Only inline YAML commands (no external scripts)
- AWS CLI v2 commands
- Standard GitHub Actions runners (ubuntu-latest)

### Must Not Use
- External shell scripts
- Third-party actions (except official actions)
- Terraform commands
- Complex logic or loops

## Security Requirements

### IAM Permissions (Minimum Required)
- `s3:DeleteObject` on `arn:aws:s3:::{bucket}/*.tflock`
- `s3:GetObject` on `arn:aws:s3:::{bucket}/*.tflock`
- `s3:HeadObject` on `arn:aws:s3:::{bucket}/*.tflock`

### Credential Handling
- Use GitHub repository secrets for AWS credentials
- Never log or expose sensitive information
- Use GitHub's built-in secret masking