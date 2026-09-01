# Spec 003 — Kubernetes Cluster Foundation

**Status**: ✅ Complete  
**Implementation**: [`src/terraform/modules/kubernetes/`](../../src/terraform/modules/kubernetes/)

## What This Spec Delivers

A self-managed 3-node Kubernetes cluster on AWS EC2 using **kubeadm** for bootstrap and **Flannel** for pod networking:

- **1 Control Plane** — `t3.small` EC2 instance in the public subnet
- **2 Worker Nodes** — `t3.micro` EC2 instances in private subnets
- **Automatic Bootstrap** — Cloud-init scripts handle kubeadm init and worker node joining
- **Flannel CNI** — VXLAN-based pod networking across nodes
- **No EKS** — Intentionally self-managed for learning and cost control

## Key Design Decision

> This is **NOT** an EKS cluster. kubeadm is used directly on EC2 instances. This is deliberate — it provides a deeper learning experience and avoids EKS management fees (~$0.10/hour).

## Key Documents

| File | Description |
|------|-------------|
| [`spec.md`](spec.md) | User stories, bootstrap requirements |
| [`plan.md`](plan.md) | Implementation plan |
| [`tasks.md`](tasks.md) | Task breakdown |
| [`quickstart.md`](quickstart.md) | How to validate the cluster post-deploy |
| [`bootstrap-troubleshooting.md`](bootstrap-troubleshooting.md) | Common kubeadm issues and fixes |
| [`infrastructure-diagram.md`](infrastructure-diagram.md) | Detailed network and compute architecture diagram |

## Dependencies

- Spec 001 (VPC Networking) — subnet IDs and security groups
- Spec 002 (Secure Deployment) — GitHub Actions workflow and IAM roles

## Consumed By

- Spec 005 (Application Infrastructure) deploys to this cluster.
