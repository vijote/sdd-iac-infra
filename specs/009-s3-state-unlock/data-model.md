# Data Model: S3 State Unlock

**Date**: 2025-01-29  
**Feature**: S3 State Unlock

## Entities

### S3StateLock

Represents a Terraform state lock object stored in S3.

**Attributes**:
- `bucket`: string - Name of the S3 bucket containing the state
- `stateKey`: string - Path to the Terraform state file (without .tflock extension)
- `lockKey`: string - Full path to the lock object (stateKey + .tflock)
- `exists`: boolean - Whether the lock object currently exists
- `operation`: string - Terraform operation that created the lock (e.g., "apply", "plan")
- `who`: string - Identifier of who holds the lock
- `created`: timestamp - When the lock was created
- `version`: string - Terraform state version

**State Transitions**:
```
[No Lock] --(terraform apply)--> [Locked] --(workflow cancelled)--> [Stale Lock]
[Stale Lock] --(unlock workflow)--> [No Lock]
[Locked] --(terraform completes)--> [No Lock]
```

### UnlockWorkflow

Represents the GitHub Actions workflow execution.

**Attributes**:
- `workflowId`: string - GitHub Actions run identifier
- `status`: enum - "running", "success", "failure"
- `bucket`: string - Target S3 bucket (from workflow input)
- `stateKey`: string - Target state key (from workflow input)
- `result`: string - Human-readable result message

## Validation Rules

### Input Validation
- `bucket` must be a valid S3 bucket name format
- `stateKey` must not end with `.tflock` (workflow adds this)
- Both inputs are required for workflow execution

### Lock Validation
- Lock object must be valid JSON if present
- Lock must contain required fields: Operation, ID, Who, Version, Created
- Lock age should be reasonable (not too old to be stale)

## Error Conditions

### Recoverable Errors
- Network timeouts (retry with exponential backoff)
- Temporary AWS service issues (retry)

### Non-recoverable Errors
- Invalid AWS credentials (fail fast)
- Insufficient permissions (fail with clear message)
- Non-existent bucket (fail with clear message)

## Data Flow

```
1. User triggers workflow with bucket and stateKey
2. Workflow checks for lock object existence
3. If lock exists:
   a. Parse lock metadata
   b. Delete lock object
   c. Report success with lock details
4. If no lock exists:
   a. Report "No lock found" as success
5. On error:
   a. Report failure with error details
```