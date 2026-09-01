# `src/terraform/` — Terraform Infrastructure as Code

This directory contains all Terraform configurations for the SDD Infrastructure project. Terraform is the **single source of truth** for all cloud resources (except IAM roles — see `src/aws_iam/`).

## Structure

```
terraform/
├── environments/    # Entry-point configs per deployment environment
│   ├── dev/         # Development environment
│   └── prod/        # Production environment
└── modules/         # Reusable, composable Terraform modules
    ├── networking/               # VPC, subnets, security groups
    ├── kubernetes/               # EC2 instances + kubeadm bootstrap
    ├── application-infrastructure/ # EBS CSI, NGINX Ingress, cert-manager
    ├── application-deployment/   # Kubernetes workload manifests
    └── state/                    # S3 remote state reference
```

## Module Dependency Chain

Modules must be applied in this order (each depends on the outputs of the previous):

```
networking → kubernetes → application-infrastructure → application-deployment
```

## Environments

Environments are the actual **Terraform root modules** (with `backend.tf` and `provider.tf`). They call the modules above with environment-specific variable values.

| Environment | Auto-deploy | Purpose |
|-------------|-------------|---------|
| `dev` | ✅ On push to `main` | Development and testing |
| `prod` | ❌ Manual only | Production workloads |

## Quick Start

```bash
cd src/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

For more details see the root [README.md](../../README.md).
