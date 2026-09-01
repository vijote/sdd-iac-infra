# Spec 004 — Destroy Pipeline

**Status**: ✅ Complete  
**Implementation**: [`.github/workflows/destroy-dev-environment.yml`](../../.github/workflows/destroy-dev-environment.yml)

## What This Spec Delivers

A **manual-only GitHub Actions workflow** that safely tears down the entire dev environment to eliminate AWS costs when the environment is not in use:

- Destroys all EC2 instances, VPC resources, and associated infrastructure via `terraform destroy`
- Requires explicit confirmation (`destroy` typed in workflow dispatch input)
- Generates a pre-destruction inventory and post-destruction report
- Creates a Terraform state backup before destruction
- Reduces monthly costs to ~$0.50 (S3 state storage only)

## Safety Mechanisms

1. **Input validation** — Only `dev` environment accepted; confirmation must be exactly `destroy`
2. **Dry-run first** — Always generates and shows destruction plan before executing
3. **State protection** — S3 state bucket is explicitly excluded from destruction
4. **10-hour timeout** — Handles complex destructions without timing out

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, safety requirements, functional requirements |
| [`plan.md`](plan.md) | Implementation plan |
| [`tasks.md`](tasks.md) | Task breakdown |

## When to Use

Trigger this workflow from **GitHub Actions → Destroy Dev Environment** when you are done working and want to eliminate all AWS costs. Re-create the environment later by triggering the Terraform Apply workflow.
