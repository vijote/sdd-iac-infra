# `modules/` — Reusable Terraform Modules

This directory contains all reusable Terraform modules. Each module is a self-contained unit of infrastructure with clearly defined inputs, outputs, and documentation.

## Module Dependency Order

Modules must be applied in this order — each consumes outputs from the previous:

```
networking → kubernetes → application-infrastructure → application-deployment
```

The `state` module is standalone and referenced independently.

## Modules

| Module | Spec | Status | Description |
|--------|------|--------|-------------|
| [`networking/`](networking/) | 001 | ✅ Complete | VPC, subnets (1 public, 2 private), security groups, route tables, internet gateway |
| [`kubernetes/`](kubernetes/) | 003 | ✅ Complete | EC2 instances, cloud-init bootstrap scripts, Flannel CNI |
| [`application-infrastructure/`](application-infrastructure/) | 005 | 🔄 In Progress | EBS CSI driver, NGINX Ingress, cert-manager, storage classes |
| [`application-deployment/`](application-deployment/) | 006 | 📋 Planned | Kubernetes workload manifests (deployments, services, storage) |
| [`state/`](state/) | 002 | ✅ Complete | Data source reference to manually-created S3 remote state bucket |

## Design Principles

- **No provider config inside modules**: Providers are configured at the environment level.
- **Output everything**: Modules export all IDs and connection details needed by downstream modules.
- **Provider-agnostic where possible**: The `networking` module supports both AWS and MiniStack for local testing.
- **Documented inputs/outputs**: Every module has a `README.md` with input/output tables.
