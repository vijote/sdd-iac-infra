# `modules/application-deployment/` — Application Workload Deployment

This Terraform module deploys **Kubernetes workload manifests** (Deployments, Services, ConfigMaps, PersistentVolumeClaims) for the demo applications. It sits at the top of the module dependency chain and is applied after `application-infrastructure/`.

## Status

📋 **Planned** — Spec 006 (Application Deployment Pipeline) is in draft.

## What It Deploys

The module manages the following application-level Kubernetes resources:

| Sub-directory | Resources |
|---------------|-----------|
| `kubernetes/deployments/` | Deployment manifests for SPA frontend, NodeJS API, MySQL |
| `kubernetes/services/` | ClusterIP / LoadBalancer Service manifests |
| `kubernetes/configmaps/` | Application configuration (env vars, nginx config, etc.) |
| `kubernetes/storage/` | PersistentVolumeClaims for stateful workloads |
| `kubernetes/namespace.yaml` | The `demo-apps` namespace declaration |

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Calls into child Kubernetes resource modules |
| `variables.tf` | Input variables (environment, image tags, secret names, domain) |
| `outputs.tf` | Service endpoints and deployment names |
| `versions.tf` | Terraform and provider version constraints |
| `kubernetes/` | Raw Kubernetes YAML manifests managed by this module |

## Dependencies

- Requires `application-infrastructure` module to be deployed first (NGINX Ingress, cert-manager, and storage classes must exist)
- Requires `kubernetes` module outputs for cluster connection details
