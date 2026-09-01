# Spec 006 — Application Deployment Pipeline

**Status**: 📋 Planned  
**Implementation**: `.github/workflows/` (to be created), `src/terraform/modules/application-deployment/`

## What This Spec Delivers

A CI/CD pipeline for deploying application workloads (SPA frontend, NodeJS API, MySQL) to the Kubernetes cluster:

- **Automated deployments** on push to `main` branch
- **Ordered deployment** — database → backend → frontend (respects service dependencies)
- **Health checks** after each deployment step — rolls back automatically on failure
- **Environment management** — dev (auto) vs prod (manual with approval)
- **Rollback** — returns to previous known-good deployment on failure

## Reuses Existing Infrastructure

This pipeline explicitly reuses the repository variables and OIDC authentication patterns already established in Spec 002 (no new secrets/roles needed):
- `STATE_BUCKET_NAME`, `AWS_BOOTSTRAP_ROLE`, `AWS_TERRAFORM_ROLE`
- Same `terraform init` / `terraform apply` pattern as existing workflows

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, functional and technical requirements |
| [`plan.md`](plan.md) | Implementation plan |
| [`tasks.md`](tasks.md) | Task breakdown |
| [`quickstart.md`](quickstart.md) | How to use the pipeline |

## Dependencies

- Spec 003 (Kubernetes Cluster)
- Spec 005 (Application Infrastructure)
- Spec 006-build-time-secrets (for secure credential injection)
- Spec 007 (Ingress Controller)
