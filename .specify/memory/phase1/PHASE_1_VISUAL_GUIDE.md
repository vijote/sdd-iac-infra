# Phase 1 Visual Guide

Quick visual reference for the three scaffolding specs and how they fit together.

---

## Spec 001: Networking Foundation

```
AWS Region (us-east-1)
┌─────────────────────────────────────────────┐
│ VPC: 10.0.0.0/16                            │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │ PUBLIC SUBNET: 10.0.1.0/24            │  │
│  │ (Control Plane will live here)        │  │
│  │                                       │  │
│  │  Route: 0.0.0.0/0 → IGW  ──→ Internet  │
│  │  SG: 6443 (API), 2379 (etcd), 4789    │  │
│  └───────────────────────────────────────┘  │
│           │                                  │
│           │                                  │
│  ┌────────┴─────────────────────────────┐  │
│  │ FLANNEL VXLAN TUNNEL (Pod Network)   │  │
│  │ 10.244.0.0/16                        │  │
│  └────────┬─────────────────────────────┘  │
│           │                                  │
│  ┌────────┴──────────────┐                 │
│  │                       │                  │
│  ▼                       ▼                  │
│  ┌──────────────────┐  ┌──────────────────┐│
│  │ PRIVATE SN 1     │  │ PRIVATE SN 2     ││
│  │ 10.0.2.0/24      │  │ 10.0.3.0/24      ││
│  │ (Worker 1)       │  │ (Worker 2)       ││
│  │ SG: 10250, 4789  │  │ SG: 10250, 4789  ││
│  └──────────────────┘  └──────────────────┘│
│                                             │
└─────────────────────────────────────────────┘

Deliverable:
✅ VPC + Subnets + Route Tables + Security Groups
✅ All networking in place for EC2 & K8s
✅ Cost: < $1/month
```

---

## Spec 002: IAM Roles & Policies

```
AWS Identity & Access Management
┌──────────────────────────────────────────────┐
│                                              │
│  Role: sdd-infra-control-plane               │
│  ├─ Trust: EC2 Service                       │
│  └─ Policies:                                │
│      ├─ ec2:Describe*                        │
│      ├─ route53:ChangeResourceRecordSets     │
│      └─ secretsmanager:GetSecretValue        │
│         (for cluster bootstrap & ops)        │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│  Role: sdd-infra-worker                      │
│  ├─ Trust: EC2 Service                       │
│  └─ Policies:                                │
│      ├─ ec2:Describe*                        │
│      └─ secretsmanager:GetSecretValue        │
│         (for node ops & pod secrets)         │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│  Role: sdd-infra-pod-service-account         │
│  ├─ Trust: Kubernetes OIDC Provider          │
│  │         (created after CP bootstrap)      │
│  └─ Policies:                                │
│      └─ secretsmanager:GetSecretValue(ro)    │
│         (for app pods to read secrets)       │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│  Instance Profiles:                          │
│  ├─ sdd-infra-cp-profile  → CP Role          │
│  └─ sdd-infra-worker-profile → Worker Role   │
│     (linked to EC2 instances in Spec 003)    │
│                                              │
└──────────────────────────────────────────────┘

Deliverable:
✅ 3 Roles with correct trust policies
✅ 3 Sets of policies (least privilege)
✅ 2 Instance profiles ready for EC2
✅ Cost: $0/month (IAM is free tier)
```

---

## Spec 003: EC2 & kubeadm Bootstrap

```
Kubernetes Cluster Bootstrap
┌────────────────────────────────────────────────────┐
│                                                    │
│  ┌─────────────────────────────────────────────┐  │
│  │ EC2: t3.small (Control Plane)               │  │
│  │ Subnet: 10.0.1.0/24 (PUBLIC)               │  │
│  │ IP: 10.0.1.x (private), EIP xxx (public)   │  │
│  │ Profile: sdd-infra-cp-profile               │  │
│  │                                             │  │
│  │ Cloud-Init Bootstrap (10 min):              │  │
│  │ 1. Install containerd                       │  │
│  │ 2. Install kubeadm, kubelet, kubectl        │  │
│  │ 3. Configure cgroups & kernel modules       │  │
│  │ 4. kubeadm init --pod-cidr=10.244.0.0/16   │  │
│  │ 5. Deploy Flannel CNI                       │  │
│  │ 6. Export kubeconfig + join token           │  │
│  │                                             │  │
│  │ Services Running:                           │  │
│  │ ├─ kube-apiserver (6443)                    │  │
│  │ ├─ etcd (2379-2380)                         │  │
│  │ ├─ kube-scheduler                           │  │
│  │ ├─ kube-controller-manager                  │  │
│  │ ├─ kubelet                                  │  │
│  │ ├─ kube-proxy                               │  │
│  │ ├─ CoreDNS (service discovery)              │  │
│  │ └─ Flannel (pod networking via VXLAN)       │  │
│  └─────────────────────────────────────────────┘  │
│                           │                        │
│         kubeadm join token │ (valid 24h)          │
│                           │                        │
│  ┌────────────────────────┴─────────────────┐    │
│  │                                          │    │
│  ▼                                          ▼    │
│  ┌──────────────────────┐  ┌──────────────────┐  │
│  │ EC2: t3.micro        │  │ EC2: t3.micro    │  │
│  │ (Worker Node 1)      │  │ (Worker Node 2)  │  │
│  │ Subnet: 10.0.2.0/24  │  │ Subnet: 10.0.3.0/│  │
│  │ IP: 10.0.2.x         │  │ IP: 10.0.3.x     │  │
│  │ Profile: worker      │  │ Profile: worker  │  │
│  │                      │  │                  │  │
│  │ Cloud-Init:          │  │ Cloud-Init:      │  │
│  │ 1. Install tools     │  │ 1. Install tools │  │
│  │ 2. Join cluster      │  │ 2. Join cluster  │  │
│  │ 3. kubelet ready     │  │ 3. kubelet ready │  │
│  │                      │  │                  │  │
│  │ Services:            │  │ Services:        │  │
│  │ ├─ kubelet           │  │ ├─ kubelet       │  │
│  │ ├─ kube-proxy        │  │ ├─ kube-proxy    │  │
│  │ ├─ containerd        │  │ ├─ containerd    │  │
│  │ └─ Flannel VXLAN     │  │ └─ Flannel VXLAN │  │
│  │    (pod networking)  │  │    (pod network) │  │
│  └──────────────────────┘  └──────────────────┘  │
│                                                    │
└────────────────────────────────────────────────────┘

Final State (kubectl get nodes):
┌──────────────────────────────────────┐
│ NAME              STATUS   ROLES     │
├──────────────────────────────────────┤
│ cp-xxxxx          Ready    control   │
│ worker-1-xxxxx    Ready    <none>    │
│ worker-2-xxxxx    Ready    <none>    │
└──────────────────────────────────────┘

Deliverable:
✅ 3 EC2 instances launched
✅ Cloud-init bootstrap completes
✅ kubeadm cluster initialized
✅ All nodes in Ready state
✅ Pod networking (Flannel) working
✅ kubeconfig exported
✅ Cost: ~$15-20/month (compute)
```

---

## Three Specs Together

```
┌─────────────────────────────────────────────────────────┐
│                  PHASE 1 COMPLETE                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Spec 001: Networking                                   │
│  ├─ VPC 10.0.0.0/16                                    │
│  ├─ Subnets (public + 2 private)                        │
│  ├─ Security Groups (CP, Worker, Ingress)               │
│  └─ Route Tables                                        │
│                                                         │
│  Spec 002: IAM                                          │
│  ├─ Control Plane Role (EC2, Route53, Secrets)         │
│  ├─ Worker Role (EC2, Secrets)                         │
│  ├─ Pod Service Account Role (Secrets read)             │
│  └─ Instance Profiles (2x)                              │
│                                                         │
│  Spec 003: EC2 & kubeadm                                │
│  ├─ CP Instance (t3.small, public IP)                   │
│  ├─ Worker 1 (t3.micro, private IP)                    │
│  ├─ Worker 2 (t3.micro, private IP)                    │
│  ├─ Cloud-init bootstrap scripts                        │
│  ├─ kubeadm initialization                              │
│  ├─ Flannel deployment                                  │
│  └─ 3-node healthy cluster                              │
│                                                         │
│  Result: Working K8s Cluster                            │
│  ├─ kubectl get nodes → 3 Ready                         │
│  ├─ kubectl get pods -n kube-system → All Running       │
│  ├─ Pod networking verified                             │
│  ├─ kubeconfig exported                                 │
│  └─ Ready for Phase 2 (Ingress & Routing)               │
│                                                         │
│  Total Cost: < $25/month                                │
│  Timeline: 2 weeks                                      │
│  Team: 1-2 engineers                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Deployment Flow

```
Developer                Repository              AWS Account
    │                        │                        │
    ├─ Write Spec 001  ──→   │                        │
    │                        │                        │
    ├─ terraform validate ──→                         │
    │                    ✓ Pass                       │
    │                                                 │
    ├─ Git push         ──→   PR Created              │
    │                    ──→   Code Review            │
    │                    ──→   Approve & Merge        │
    │                                                 │
    ├─ terraform apply  ──────────────────────────→  VPC
    │                              ↓ wait 1 min      Subnets
    │                    ← ─────── ✓ Created         SGs
    │                                                 │
    ├─ Write Spec 002  ──→  (parallel with 001)       │
    │ (repeat pattern)                                │
    │                                                 │
    │                                                 │
    ├─ Write Spec 003  ──→  (after 001 & 002)        │
    │                                                 │
    ├─ terraform apply  ──────────────────────────→  EC2 ×3
    │                              ↓ wait 10 min     kubeadm
    │                    ← ─────── ✓ Bootstrapping   Flannel
    │                                                 │
    ├─ kubectl get nodes ←─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ 3 Ready
    │                                                 │
    └─ Phase 1 Complete ✅                            │
```

---

## Resource Naming Convention

All resources follow this naming pattern for clarity:

```
sdd-infra-<type>-<env>

Examples:
─────────────────────────────────────────
VPC:           sdd-infra-vpc-aws
Subnets:       sdd-infra-subnet-public-aws
               sdd-infra-subnet-private-1-aws
               sdd-infra-subnet-private-2-aws
SG:            sdd-infra-cp-sg-aws
               sdd-infra-worker-sg-aws
               sdd-infra-ingress-sg-aws
Roles:         sdd-infra-control-plane
               sdd-infra-worker
               sdd-infra-pod-service-account
Profiles:      sdd-infra-cp-profile-aws
               sdd-infra-worker-profile-aws
Instances:     sdd-infra-cp-1-aws
               sdd-infra-worker-1-aws
               sdd-infra-worker-2-aws
```

All resources tagged with:
- `Project: sdd-infra`
- `Environment: aws` (or ministack)
- `Phase: 1-foundation`
- `ManagedBy: terraform`

---

## Quick Reference: Commands

### Validate Spec 001
```bash
cd src/terraform/environments/aws
terraform init
terraform plan -target=module.networking
terraform apply -target=module.networking
```

### Validate Spec 002
```bash
terraform plan -target=module.iam
terraform apply -target=module.iam
```

### Validate Spec 003
```bash
terraform plan -target=module.compute
terraform apply -target=module.compute
# Wait 10-15 minutes for bootstrap
```

### Verify Full Cluster
```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
kubectl get pods -n kube-system
kubectl run -it --rm debug --image=busybox -- ping 10.96.0.10
```

---

**Version:** 1.0  
**Date:** 2026-08-20  
**Status:** Ready for Implementation
