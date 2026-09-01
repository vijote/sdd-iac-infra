# `src/aws_iam/` — Manual IAM Role Definitions

This directory contains **CloudFormation YAML templates** for IAM roles that are intentionally **not managed by Terraform**.

## Why Manual Provisioning?

These IAM roles are manually provisioned to avoid a circular dependency:

- Terraform needs an IAM role to deploy resources.
- If Terraform also managed those roles, they would need to exist *before* Terraform can run — a chicken-and-egg problem.
- The solution: provision these roles **once, manually** (via CloudFormation or the AWS Console), then let Terraform assume them for all subsequent deployments.

## Files

| File | Description |
|------|-------------|
| [`oidc-and-general-role.yml`](oidc-and-general-role.yml) | Creates the GitHub OIDC identity provider and a bootstrap IAM role (`gha-bootstrap-role`) used for initial AWS authentication from GitHub Actions |
| [`terraform-role-for-github.yml`](terraform-role-for-github.yml) | Creates the `TerraformDeployRole` — the least-privilege IAM role that Terraform assumes to provision all other infrastructure |

## Authentication Flow

```
GitHub Actions → OIDC → gha-bootstrap-role → assume → TerraformDeployRole → Terraform operations
```

## Usage

These templates are deployed **once** per AWS account via the AWS Console or CLI:

```bash
aws cloudformation deploy \
  --template-file oidc-and-general-role.yml \
  --stack-name sdd-oidc-roles \
  --capabilities CAPABILITY_NAMED_IAM
```

> ⚠️ **Do not** move these resources into Terraform. The circular dependency is intentional and architectural.
