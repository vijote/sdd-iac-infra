# Phase 1 Scaffolding Summary

**Date Created:** 2026-08-20  
**Status:** Ready for Implementation  
**Duration:** Weeks 1-2  
**Team Capacity:** 1-2 engineers  

---

## Executive Summary

Phase 1 breaks the foundational infrastructure into **three incremental, independently-testable specs**. Each spec has clear dependencies, deliverables, and success criteria. Developers can work on Specs 001 & 002 in parallel, then merge and test Spec 003.

**Total Scope:** ~2 weeks of development + testing  
**Estimated Cost:** < $25/month (compute + networking)  
**Learning Outcome:** Understanding AWS networking, IAM, EC2, and Kubernetes bootstrap via kubeadm

---

## Scaffolding Specs Overview

### Spec 001: VPC & Networking Foundation
**Status:** Ready  
**Dependencies:** None  
**Deliverable:** `src/terraform/modules/networking/`

```
What it creates:
├── VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24) — Control Plane
├── Private Subnets (10.0.2.0/24, 10.0.3.0/24) — Workers
├── Internet Gateway
├── Route Tables (public + private)
└── Security Groups
    ├── Control Plane SG (6443, 2379-2380, 4789)
    ├── Worker SG (10250, 4789)
    └── Ingress SG (80, 443)

Success Criteria:
✅ terraform validate passes
✅ VPC and subnets created in AWS
✅ Security groups have correct rules
✅ Cost < $1/month (VPC is mostly free)
```

### Spec 002: IAM Roles & Policies
**Status:** Ready  
**Dependencies:** None (parallel with 001)  
**Deliverable:** `src/terraform/modules/iam/`

```
What it creates:
├── Control Plane Role
│   └── Permissions: EC2 describe, Route53, Secrets Manager
├── Worker Node Role
│   └── Permissions: EC2 describe, Secrets Manager
├── Pod Service Account Role (IRSA)
│   └── Permissions: Secrets Manager read-only
└── Instance Profiles (link roles to EC2)

Success Criteria:
✅ terraform validate passes
✅ Three roles created in AWS IAM
✅ Policies attached with least-privilege scope
✅ Instance profiles ready for EC2 attachment
✅ Cost: $0/month (IAM is free tier)
```

### Spec 003: EC2 Instances & kubeadm Bootstrap
**Status:** Ready  
**Dependencies:** Specs 001 & 002  
**Deliverable:** `src/terraform/modules/compute/`

```
What it creates:
├── Control Plane Instance (t3.small, public IP)
│   └── Cloud-init:
│       ├── Install containerd, kubeadm, kubelet
│       ├── kubeadm init
│       ├── Deploy Flannel CNI
│       └── Export kubeconfig + join token
├── Worker Node 1 (t3.micro, private IP)
│   └── Cloud-init:
│       ├── Install containerd, kubeadm, kubelet
│       └── kubeadm join (via token from CP)
└── Worker Node 2 (t3.micro, private IP)
    └── Cloud-init: (same as Worker 1)

Success Criteria:
✅ terraform validate passes
✅ 3 EC2 instances launched
✅ Cloud-init bootstrap completes (~10 min)
✅ kubectl get nodes shows 3 Ready nodes
✅ Flannel deployed and pod networking works
✅ kubeconfig exported and accessible
✅ Cost: ~$15-20/month (1 t3.small + 2 t3.micro)
```

---

## Dependency Graph

```
Spec 001 (VPC & Networking)     Spec 002 (IAM Roles)
    │                                 │
    │   (can develop in parallel)     │
    │                                 │
    └─────────────┬─────────────────┘
                  │
                  │ (depends on both)
                  ▼
          Spec 003 (EC2 & kubeadm)
                  │
                  ▼
          Fully Working K8s Cluster
```

---

## Folder Structure

```
sdd-infra/
├── .coda/docs/
│   ├── SPECIFICATION.md                        (Overall project spec)
│   ├── DECISION_LOG.md                         (Major decisions D001-D007)
│   ├── CONSTITUTION.md                         (Principles & governance)
│   ├── SCAFFOLDING_SPEC_001_NETWORKING.md      ⭐ NEW
│   ├── SCAFFOLDING_SPEC_002_IAM_ROLES.md       ⭐ NEW
│   ├── SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md   ⭐ NEW
│   └── SCAFFOLDING_DECISION_LOG.md             ⭐ NEW (refinement decisions)
│
└── src/
    ├── README.md                               ⭐ NEW (quick start guide)
    ├── terraform/
    │   ├── modules/
    │   │   ├── networking/         ⭐ TO BUILD (Spec 001)
    │   │   │   ├── main.tf
    │   │   │   ├── security_groups.tf
    │   │   │   ├── route_tables.tf
    │   │   │   ├── variables.tf
    │   │   │   └── outputs.tf
    │   │   ├── iam/                ⭐ TO BUILD (Spec 002)
    │   │   │   ├── main.tf
    │   │   │   ├── variables.tf
    │   │   │   ├── outputs.tf
    │   │   │   └── policies/
    │   │   └── compute/            ⭐ TO BUILD (Spec 003)
    │   │       ├── main.tf
    │   │       ├── variables.tf
    │   │       ├── outputs.tf
    │   │       └── cloud-init/
    │   │           ├── common.sh
    │   │           ├── control-plane.sh
    │   │           └── worker.sh
    │   │
    │   ├── environments/
    │   │   ├── aws/
    │   │   │   ├── main.tf         (calls all modules)
    │   │   │   ├── terraform.tfvars (AWS-specific values)
    │   │   │   └── backend.tf
    │   │   └── ministack/
    │   │       ├── main.tf
    │   │       ├── terraform.tfvars (ministack values)
    │   │       └── backend.tf
    │   │
    │   └── shared/
    │       └── versions.tf         (Terraform version constraints)
    │
    ├── k8s/
    │   ├── manifests/
    │   │   ├── ingress/            (Phase 2)
    │   │   ├── services/           (Phase 2)
    │   │   └── configmaps/         (Phase 2)
    │   └── helm/                   (Phase 2+)
    │
    └── scripts/
        ├── deploy.sh               (Main orchestration)
        ├── validate.sh             (Testing & verification)
        └── cloud-init/             (Linked from terraform module)
```

---

## Implementation Timeline

### Week 1: Specs 001 & 002 (Parallel)

**Spec 001 Track (Networking)**
- [ ] Day 1-2: Write `src/terraform/modules/networking/main.tf` (VPC, subnets, IGW)
- [ ] Day 2-3: Write security_groups.tf, route_tables.tf
- [ ] Day 3: Write variables.tf, outputs.tf
- [ ] Day 3: Test: `terraform validate`, `terraform plan`
- [ ] Day 4: Deploy to AWS sandbox, verify resources exist
- [ ] Day 4: Documentation complete

**Spec 002 Track (IAM — Parallel)**
- [ ] Day 1-2: Write `src/terraform/modules/iam/main.tf` (roles, policies)
- [ ] Day 2-3: Write policy JSON files
- [ ] Day 3: Write variables.tf, outputs.tf
- [ ] Day 3: Test: `terraform validate`, `terraform plan`
- [ ] Day 4: Deploy to AWS sandbox, verify roles exist
- [ ] Day 4: Documentation complete

**End of Week 1:**
- [ ] Both specs validated and deployed
- [ ] PR reviews complete; code merged
- [ ] Cost estimate confirmed

### Week 2: Spec 003 (EC2 & kubeadm)

- [ ] Day 1-2: Write `src/terraform/modules/compute/main.tf` (EC2 instances, profiles)
- [ ] Day 2-3: Write cloud-init scripts (common.sh, control-plane.sh, worker.sh)
- [ ] Day 3: Write variables.tf, outputs.tf
- [ ] Day 3: Test: `terraform validate`, `terraform plan`
- [ ] Day 4: Deploy to AWS; monitor bootstrap (10 min)
- [ ] Day 4: Verify: `kubectl get nodes` (all Ready)
- [ ] Day 4: Test pod networking, export kubeconfig
- [ ] Day 5: Final integration testing & documentation
- [ ] Day 5: PR review & merge

**End of Week 2:**
- [ ] Full cluster bootstrapped and healthy
- [ ] All nodes in Ready state
- [ ] kubeconfig exported for kubectl access
- [ ] Phase 1 Foundation complete ✅

---

## Testing Checklist

### Per-Spec Testing

**Spec 001 (Networking):**
```bash
terraform validate ✓
terraform plan ✓
Deploy to AWS
aws ec2 describe-vpcs --filters Name=tag:Project,Values=sdd-infra ✓
aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id> ✓
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<vpc-id> ✓
Cost check: <$1/month ✓
```

**Spec 002 (IAM):**
```bash
terraform validate ✓
terraform plan ✓
Deploy to AWS
aws iam list-roles --query "Roles[?RoleName=='sdd-infra-*']" ✓
aws iam get-role-policy --role-name sdd-infra-control-plane ... ✓
Policy content reviewed (least privilege) ✓
Cost check: $0/month ✓
```

**Spec 003 (Compute):**
```bash
terraform validate ✓
terraform plan ✓
Deploy to AWS
Monitor cloud-init: aws ec2 get-console-output --instance-id <id> ✓
Wait 10 minutes for bootstrap
kubectl get nodes → 3 Ready ✓
kubectl get pods -n kube-system → All Running ✓
Pod networking test: kubectl run -it debug ... ✓
Export kubeconfig ✓
Cost check: ~$15-20/month ✓
```

### Integration Test

```bash
All three specs deployed
Full cluster health check
kubectl describe node <each-node>  → No issues
kubectl logs -n kube-system <pod>  → No errors
Flannel VXLAN tunnel established
Cost validation: <$25/month
Documentation complete
Sign-off ✓
```

---

## Key Decisions & Trade-offs

| Decision | Choice | Rationale | Trade-off |
|----------|--------|-----------|-----------|
| **Scope Granularity** | 3 Specs | Incremental testing, clear dependencies | Slightly more coordination |
| **Provider Agnosticism** | Modules don't hardcode AWS | Works for ministack too; DRY principle | Some AWS features harder to leverage |
| **Testing Strategy** | Unit + Integration | Catches real AWS errors early | Slower than unit-only; costs $ |
| **Instance Sizing** | t3.small CP, t3.micro workers | Cost optimization | May hit resource limits under load |
| **Single Control Plane** | No HA | Simpler to learn; acceptable for MVP | Cluster loss if CP fails |
| **Public CP IP** | Yes, for kubectl access | Easy access from local | Security trade-off (mitigated by SG rules) |

---

## Success Definition

✅ **Phase 1 is Complete when:**

1. All three specs are implemented, tested, and documented
2. Full cluster boots successfully and consistently
3. All nodes are Ready, all pods Running
4. Pod-to-pod networking verified (Flannel working)
5. kubeconfig exported and kubectl commands work locally
6. Cost is tracking < $50/month total (Phase 1 scope)
7. Team understands the architecture and can explain each component
8. Code is merged, all tests pass, all docs updated

---

## What Happens Next (Phase 2+)

After Phase 1 is validated:

- **Phase 2 (Weeks 3-4):** nginx-ingress, Route53 DNS, load balancer
- **Phase 3 (Weeks 4-5):** AWS Secrets Manager, IRSA pod authentication
- **Phase 4 (Week 6+):** CI/CD pipeline, runbooks, performance tuning

Each phase will follow the same spec-driven approach.

---

## Questions & Clarifications

**Q: Can we skip the specs and just write Terraform?**  
A: No. Specs are the contract; they guide implementation and testing. Skipping them leads to rework.

**Q: Why three specs instead of one?**  
A: Incremental validation catches errors early. If Spec 001 fails, we know it's networking. If it passes but Spec 003 fails, we know it's compute/kubeadm.

**Q: Can we deploy to real AWS now?**  
A: Yes, but use a sandbox account. Phase 1 cost should be < $25/month. Monitor billing closely.

**Q: What if kubeadm bootstrap fails?**  
A: Check cloud-init logs, verify security groups, retry. Spec 003 includes troubleshooting steps.

**Q: Do we need ministack?**  
A: Optional. Useful for fast `terraform validate` feedback. Not required for "done."

---

## Artifacts

All specs and supporting docs are in `.coda/docs/`:

- `SCAFFOLDING_SPEC_001_NETWORKING.md` (13.5 KB)
- `SCAFFOLDING_SPEC_002_IAM_ROLES.md` (12.2 KB)
- `SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md` (16.7 KB)
- `SCAFFOLDING_DECISION_LOG.md` (15.6 KB)
- `PHASE_1_SCAFFOLDING_SUMMARY.md` (this file)

Implementation code goes in `src/terraform/modules/`.

---

**Prepared By:** Coda  
**Date:** 2026-08-20  
**Status:** Ready for Team Review & Implementation
