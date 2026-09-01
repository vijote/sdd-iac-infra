# Spec 005 — Application Infrastructure Foundation

**Status**: 🔄 In Progress  
**Implementation**: [`src/terraform/modules/application-infrastructure/`](../../src/terraform/modules/application-infrastructure/)

## What This Spec Delivers

The Kubernetes platform layer that sits on top of the cluster and enables application workloads:

- **EBS CSI Driver** — Enables PersistentVolume provisioning from AWS EBS (for MySQL and other stateful apps)
- **NGINX Ingress Controller** — Routes external HTTP/HTTPS traffic into the cluster
- **cert-manager** — Automatically issues and renews Let'\''s Encrypt SSL certificates
- **Storage Classes** — Pre-configured `gp3`, `io2`, `sc1`, `st1` storage tiers
- **Path-based Routing** — SPA at `/`, API at `/api/*`

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, functional requirements |
| [`plan.md`](plan.md) | Implementation plan |
| [`tasks.md`](tasks.md) | Task breakdown (active) |
| [`quickstart.md`](quickstart.md) | Deployment and validation guide |
| [`research.md`](research.md) | EBS CSI vs other storage drivers, ingress options considered |

## Dependencies

- Spec 003 (Kubernetes Cluster) — cluster must be running and accessible
- AWS IAM permissions for EBS volume management

## Consumed By

- Spec 006 (Application Deployment Pipeline) deploys workloads on top of this foundation.
- Spec 007 (Ingress Controller) extends ingress capabilities.
