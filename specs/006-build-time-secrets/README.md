# Spec 006-BTS — Build-time Secrets Manager

**Status**: 📋 Planned

## What This Spec Delivers

AWS Secrets Manager integration at **container image build time** — secrets are fetched and injected into containers during the Docker build process, not at runtime:

- Secrets fetched from AWS Secrets Manager during `docker build`
- Injected as environment variables or files inside containers
- Uses IAM role-based authentication (no IRSA, no hardcoded credentials)
- Secrets never appear in container image layers or build logs
- Supports secret rotation by rebuilding images

## Key Design Decision

> **No IRSA** (IAM Roles for Service Accounts). Authentication is role-based at build time via the GitHub Actions OIDC role, keeping the runtime cluster simpler and avoiding the complexity of IRSA setup on a self-managed cluster.

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, functional and technical requirements |

## Dependencies

- Spec 002 (Secure Deployment) — for the IAM role that accesses Secrets Manager
- Spec 005 (Application Infrastructure) — for the applications that consume secrets
