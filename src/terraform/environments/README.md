# `environments/` — Terraform Environment Entry Points

Each subdirectory here is a self-contained **Terraform root module** that targets a specific deployment environment. They wire together the reusable modules from `../modules/` with environment-specific configuration.

## Available Environments

| Environment | Description | Deployment |
|-------------|-------------|-----------|
| [`dev/`](dev/) | Development environment — lower-cost instance types, auto-deployed on push to `main` | Automated (GitHub Actions) |
| [`prod/`](prod/) | Production environment — larger instances, requires manual approval | Manual trigger only |

## Common File Structure

Every environment directory contains:

| File | Purpose |
|------|---------|
| `backend.tf` | Remote S3 state backend configuration |
| `provider.tf` | AWS + Kubernetes provider configuration |
| `main.tf` | Module calls (networking, kubernetes, app-infra, app-deployment) |
| `variables.tf` | Variable declarations |
| `application-deployment.tf` | Application workload module call |
| `outputs.tf` | Environment-level outputs |

## Environment Isolation

- Each environment uses a **separate Terraform state key** in the shared S3 bucket.
- Resource tagging (`Environment = dev/prod`) provides cost attribution.
- Production deployments require the `prod` environment GitHub Actions approval gate.
