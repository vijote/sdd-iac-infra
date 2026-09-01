# Spec 002 — Secure Deployment Foundation

**Status**: ✅ Complete  
**Implementation**: `.github/workflows/`, `src/aws_iam/`

## What This Spec Delivers

The CI/CD security layer that enables GitHub Actions to deploy infrastructure to AWS **without storing any static credentials**:

- **GitHub OIDC Authentication** — Temporary AWS credentials per workflow run
- **Least-Privilege IAM Roles** — `gha-bootstrap-role` (OIDC) → assumes → `TerraformDeployRole`
- **Remote Terraform State** — S3 backend with native object locking, environment-isolated
- **Multi-Environment Support** — Dev (auto) and Prod (manual) deployment gates

## Key Design Decision

> IAM roles are **manually provisioned** via CloudFormation (in `src/aws_iam/`) — not by Terraform — to avoid a circular dependency between the OIDC provider and the Terraform execution role.

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, OIDC requirements, state management requirements |
| [`plan.md`](plan.md) | Implementation plan |
| [`tasks.md`](tasks.md) | Task breakdown |
| [`quickstart.md`](quickstart.md) | How to configure OIDC and set up GitHub secrets |

## Dependencies

- Spec 001 (VPC Networking) must be deployed before Terraform apply can use this foundation.

## Consumed By

- All subsequent specs rely on the GitHub Actions workflows defined here.
