# `.github/environments/` — GitHub Actions Environment Configuration

This directory contains GitHub Actions **environment definition files** for the `dev` and `prod` deployment environments. These YAML files configure environment-level protection rules, required reviewers, and secrets scoping in GitHub.

## Files

| File | Environment | Description |
|------|-------------|-------------|
| [`dev.yml`](dev.yml) | Development | Minimal protection — auto-deploy on push to `main`. Used for rapid iteration and testing. |
| [`prod.yml`](prod.yml) | Production | Stricter protection — requires manual trigger and reviewer approval before any deployment proceeds. |

## Environment Strategy

| Setting | Dev | Prod |
|---------|-----|------|
| Auto-deploy | ✅ On `main` push | ❌ Manual only |
| Required reviewers | None | Required |
| Deployment branch | `main` | `main` |
| Secrets scope | Dev-specific | Prod-specific |

## How This Works

GitHub Actions workflows reference these environment names (e.g., `environment: prod`) to automatically enforce:
- Wait timers before deployment
- Required reviewer approvals  
- Environment-scoped secrets (so prod secrets are never accessible in dev workflows)

See `.github/workflows/` for how workflows consume these environments.
