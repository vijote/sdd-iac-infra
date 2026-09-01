# Spec 009 — S3 State Unlock

**Status**: ✅ Complete  
**Implementation**: [`.github/workflows/unlock-terraform-state.yml`](../../.github/workflows/unlock-terraform-state.yml)

## What This Spec Delivers

An emergency GitHub Actions workflow that removes **stale Terraform state locks** from S3 when a workflow is cancelled mid-execution:

- Triggered manually via `workflow_dispatch`
- Takes `bucket` and `state_key` as inputs
- Removes the S3 lock object using AWS CLI commands (inline YAML only — no external scripts)
- Reports success or handles the "no lock exists" case gracefully
- Completes in under 30 seconds

## When to Use

When you cancel a running Terraform workflow (e.g., `terraform-apply.yml`) mid-execution, the S3 state lock may not be released automatically. This blocks all future Terraform operations with a "state is locked" error. Run this workflow to recover.

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, requirements, edge cases |
| [`plan.md`](plan.md) | Implementation plan |
| [`tasks.md`](tasks.md) | Task breakdown |
| [`quickstart.md`](quickstart.md) | Step-by-step unlock guide |

## Note on Architecture

> This project uses **native S3 locking** (not DynamoDB). The lock is a special object in the S3 bucket — this workflow deletes that object to release the lock.
