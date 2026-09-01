# `src/` — Source Code

This directory contains all deployable source code for the SDD Infrastructure project.

## Structure

```
src/
├── aws_iam/         # CloudFormation YAML templates for manually-provisioned IAM roles
└── terraform/       # All Terraform Infrastructure-as-Code
    ├── environments/ # Environment-specific entry points (dev / prod)
    └── modules/      # Reusable Terraform modules
```

## Sub-directories

| Directory | Purpose |
|-----------|---------|
| [`aws_iam/`](aws_iam/) | CloudFormation templates for IAM roles that cannot be managed by Terraform (avoids circular dependencies with OIDC) |
| [`terraform/`](terraform/) | Root Terraform code. Contains `environments/` (per-env configs) and `modules/` (reusable building blocks) |

## Key Design Decisions

- **IAM is manually provisioned** via CloudFormation (in `aws_iam/`) to avoid the circular dependency between the GitHub OIDC provider and the Terraform role that would deploy it.
- **Terraform is the source of truth** for all other infrastructure (VPC, EC2, Kubernetes manifests, etc.).
- The `modules/` directory is provider-agnostic where possible, allowing local testing against MiniStack.
