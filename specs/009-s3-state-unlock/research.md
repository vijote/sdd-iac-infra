# Research: S3 State Unlock

**Date**: 2025-01-29  
**Feature**: S3 State Unlock

## Terraform S3 State Locking Mechanism

### Decision: Use AWS CLI to remove lock objects

**Rationale**: 
- Terraform state locks in S3 are implemented as simple objects with `.tflock` extension
- The lock contains metadata about who holds the lock (Operation, ID, Who, Version, Created)
- AWS CLI provides direct S3 object manipulation without requiring Terraform installation
- This approach is lightweight and doesn't require additional dependencies

**Alternatives considered**:
- Terraform force unlock command: Requires Terraform installation and state file access
- Custom script: Violates the requirement of "no external scripts"
- Manual AWS console: Not automatable and violates IaC principles

## GitHub Actions Workflow Structure

### Decision: Use workflow_dispatch for manual triggering

**Rationale**:
- workflow_dispatch allows manual triggering from GitHub UI
- Provides input parameters for bucket name and state key
- Integrates naturally with existing GitHub Actions infrastructure
- No additional authentication setup needed beyond existing AWS credentials

**Alternatives considered**:
- repository_dispatch: More complex, requires event handling
- scheduled workflow: Not appropriate for emergency unlock
- API trigger: Overkill for simple manual operation

## AWS CLI Commands for State Lock Removal

### Decision: Use s3api delete-object with conditional logic

**Rationale**:
- `aws s3api delete-object` can remove specific lock objects
- Can check for lock existence before attempting deletion
- Provides clear error messaging for debugging
- Works with standard AWS CLI available in GitHub Actions runners

**Command pattern**:
```bash
# Check if lock exists
aws s3api head-object --bucket $BUCKET --key $STATE_KEY.tflock

# Remove lock if exists
aws s3api delete-object --bucket $BUCKET --key $STATE_KEY.tflock
```

## Error Handling Strategies

### Decision: Graceful handling of no-lock scenario

**Rationale**:
- Lock might not exist if workflow wasn't actually locked
- Should not fail the workflow if there's nothing to unlock
- Provides clear feedback about lock status

**Implementation approach**:
- Use conditional logic to check lock existence first
- Report "No lock found" as success, not failure
- Only fail on actual errors (permissions, network, etc.)

## Security Considerations

### Decision: Minimal IAM permissions

**Rationale**:
- Follows least-privilege principle from Constitution
- Only needs `s3:DeleteObject` permission on specific lock objects
- No need for full S3 bucket access

**Required permissions**:
- `s3:DeleteObject` on `arn:aws:s3:::bucket-name/*.tflock`
- `s3:GetObject` and `s3:HeadObject` for lock checking

## Performance Optimization

### Decision: Single-step lock removal

**Rationale**:
- Lock removal is a simple S3 object deletion
- No need for complex retry logic
- Completes in milliseconds, well under 30-second requirement

## Integration with Existing Workflows

### Decision: Standalone workflow

**Rationale**:
- Doesn't interfere with existing Terraform workflows
- Can be run independently when needed
- Clear separation of concerns

**Trigger mechanism**:
- Manual via workflow_dispatch
- No automatic triggers to avoid accidental lock removal