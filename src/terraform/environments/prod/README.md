# `environments/prod/` — Production Environment

This directory contains the Terraform root module for the **production** environment. It mirrors the `dev/` environment structure but with production-grade settings and manual-only deployment controls.

## Files

| File | Description |
|------|-------------|
| `backend.tf` | S3 remote state backend with a `prod`-scoped state key |
| `provider.tf` | AWS provider targeting the production IAM role |
| `main.tf` | Module calls for all infrastructure layers |
| `variables.tf` | Variable declarations (larger instance types, prod CIDR ranges, etc.) |
| `application-deployment.tf` | Calls the application-deployment module for prod workloads |

## Key Differences from `dev/`

- **No auto-deployment**: Production is never deployed automatically. All changes require a manual `workflow_dispatch` trigger with explicit environment selection.
- **Approval gate**: The `prod` GitHub Actions environment requires reviewer approval.
- **Larger instances**: Control plane uses `t3.medium`, workers use `t3.small`.
- **Separate state**: State stored under a `prod/` prefix in the shared S3 bucket.

## Deployment

```bash
# Via GitHub Actions (recommended)
# Navigate to Actions → Terraform Apply → Run Workflow → Select "prod"

# Local (emergency only)
cd src/terraform/environments/prod
terraform init
terraform plan
terraform apply
```

> ⚠️ **Never** destroy the production environment using the destroy pipeline. Only `dev` destruction is supported.
