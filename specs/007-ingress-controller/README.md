# Spec 007 — Ingress Controller Integration

**Status**: 📋 Planned

## What This Spec Delivers

Extended ingress capabilities with Route53 DNS integration:

- **NGINX Ingress Controller** (Helm chart, high availability)
- **Route53 DNS** — Single A record pointing to the load balancer
- **Path-based routing** — `/` → SPA frontend, `/api` → NodeJS backend
- **SSL/TLS termination** — Certificates from Let'\''s Encrypt or AWS ACM
- **HTTP → HTTPS redirect**

## Relationship to Spec 005

> Spec 005 already includes an NGINX Ingress Controller. Spec 007 extends it with **Route53 DNS management** and formalizes the ingress configuration as an independent, testable component.

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, functional and technical requirements including Route53 specs |

## Dependencies

- Spec 001 (VPC Networking) — security groups and VPC
- Spec 003 (Kubernetes Cluster) — the cluster to deploy into
- Spec 005 (Application Infrastructure) — applications to route traffic to
- An AWS Route53 hosted zone for the domain
