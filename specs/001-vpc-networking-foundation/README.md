# Spec 001 — VPC Networking Foundation

**Status**: ✅ Complete  
**Implementation**: [`src/terraform/modules/networking/`](../../src/terraform/modules/networking/)

## What This Spec Delivers

A foundational AWS VPC with all the networking primitives required for the Kubernetes cluster:

- **VPC** — `10.0.0.0/16` CIDR, DNS hostnames enabled
- **1 Public Subnet** — `10.0.1.0/24` — hosts the control plane and ingress controller
- **2 Private Subnets** — `10.0.2.0/24`, `10.0.3.0/24` — host worker nodes
- **Internet Gateway** — Provides public internet access for the public subnet
- **Route Tables** — Public subnet routes to IGW; private subnets use local routing only
- **3 Security Groups** — Control Plane, Worker Node, Ingress (least-privilege rules)

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, acceptance criteria, functional requirements |
| [`plan.md`](plan.md) | Step-by-step implementation plan |
| [`tasks.md`](tasks.md) | Granular task breakdown |
| [`quickstart.md`](quickstart.md) | Quick deployment guide |
| [`data-model.md`](data-model.md) | VPC entity definitions |

## Dependencies

- None — this is the foundational layer.

## Consumed By

- Spec 003 (Kubernetes Cluster) — uses subnet IDs and security group IDs as inputs.
