# Decision Log: Self-Managed Kubernetes on AWS

## Project Overview
- **Type:** Learning project (internal)
- **Goal:** Understand Kubernetes internals and control costs
- **Infrastructure:** Self-managed K8s on AWS EC2 (1 control plane + 2 workers)
- **Apps:** 3 minimal demo apps (frontend, backend, database) in separate repos

---

## D001: Pod Networking — Choose Flannel
**Date:** 2026-08-20  
**Context:** Kubernetes pods need to communicate across nodes. Must select a CNI plugin.

**Options Considered:**
- **Flannel:** Simple, lightweight, VXLAN tunneling, "just works" — Pros: easy to learn, minimal overhead. Cons: basic networking, no network policies.
- **Calico:** More advanced, supports network policies — Pros: production-grade, flexible. Cons: steeper learning curve, more complexity.
- **Weave:** Mature, encrypted by default — Pros: security. Cons: heavier resource usage.

**Decision:** Flannel  
**Rationale:** Learning project with minimal resource constraints (t3.micro/small). Flannel is the fastest to understand and deploy.  
**Implications:** No network policies possible, but acceptable for a demo environment. If security policies become critical later, we'd need to migrate to Calico.  
**Alternatives Rejected:** Calico added complexity for learning phase; Weave's overhead didn't fit cost goals.

---

## D002: Kubernetes Provisioning — End-to-End Terraform + kubeadm
**Date:** 2026-08-20  
**Context:** How to bootstrap the K8s cluster on EC2 instances?

**Options Considered:**
- **Terraform + kubeadm (end-to-end):** Terraform provisions VMs; cloud-init runs kubeadm scripts — Pros: fully declarative, reproducible, single tool. Cons: more Terraform code, debugging can be complex.
- **Terraform (VMs only) + separate Ansible playbook:** Split provisioning from cluster setup — Pros: separation of concerns, easier to test. Cons: multiple tools, more manual steps.
- **Managed K8s (EKS):** AWS handles everything — Pros: simpler, less to learn. Cons: defeats the learning goal, higher cost than self-managed.

**Decision:** Terraform + kubeadm (end-to-end)  
**Rationale:** Learning project benefits from seeing the full setup in code. Single tool means easier reproducibility. kubeadm is the standard bootstrap tool for self-managed K8s.  
**Implications:** Cloud-init scripts will be embedded in Terraform. More debugging complexity if something fails during node initialization.  
**Alternatives Rejected:** Separate Ansible adds tool complexity; EKS defeats the learning goal.

---

## D003: Ingress & Routing — Terraform-Managed nginx-ingress
**Date:** 2026-08-20  
**Context:** Apps need a single Route53 entry that routes / → frontend and /api → backend.

**Options Considered:**
- **Terraform sets up nginx-ingress controller + ingress rules:** Declarative, fully automated — Pros: complete automation, reproducible. Cons: Terraform manages Helm charts (added complexity).
- **Manual ingress controller setup + Terraform for ingress rules:** Hybrid approach — Pros: simpler Terraform. Cons: not fully reproducible.
- **AWS Application Load Balancer (ALB):** Use AWS native load balancing — Pros: AWS-native, easy. Cons: less educational (doesn't teach K8s ingress), higher cost.

**Decision:** Terraform-managed nginx-ingress  
**Rationale:** Full automation fits the learning goal. Terraform can use Helm provider to deploy nginx-ingress, then manage ingress rules. Single entry point via Route53 + hostname routing is cleaner.  
**Implications:** Terraform code will include Helm provider. Route53 DNS points to the ingress controller's load balancer.  
**Alternatives Rejected:** Manual setup breaks reproducibility. ALB skips K8s ingress learning.

---

## D004: Secret Management — AWS Secrets Manager
**Date:** 2026-08-20  
**Context:** Apps need to store and access secrets (DB passwords, API keys, etc.).

**Options Considered:**
- **AWS Secrets Manager:** AWS-native, managed, integrates with IAM — Pros: secure, scalable, no extra tools. Cons: pods need IAM role to fetch secrets.
- **Kubernetes Secrets (base64-encoded):** Built-in, simple — Pros: no external dependency. Cons: secrets are base64-encoded, not encrypted at rest by default.
- **Sealed Secrets:** Encrypted K8s secrets, more secure — Pros: stronger encryption, stays in K8s. Cons: extra tool to manage.

**Decision:** AWS Secrets Manager  
**Rationale:** Learning project benefits from understanding AWS integration with K8s. Secrets Manager is production-grade and fits the AWS infrastructure goal. Pods will use IAM service accounts to fetch secrets.  
**Implications:** Terraform will provision the secrets; pods need IRSA (IAM Roles for Service Accounts) to access them. Extra IAM setup complexity but worth the learning.  
**Alternatives Rejected:** Bare K8s Secrets not secure enough for production learning. Sealed Secrets adds tool complexity.

---

## D005: Terraform CI/CD Pipeline
**Date:** 2026-08-20  
**Context:** How to safely apply Terraform changes to the live infrastructure?

**Options Considered:**
- **Basic: terraform plan + apply on merge:** Simple, fast feedback — Pros: minimal setup, clear flow. Cons: no validation gates, risky.
- **Advanced: plan + cost estimation + approval + apply:** Production-grade safety — Pros: catches errors early, cost awareness. Cons: more complex, slower.
- **Manual: Run locally only:** Full control — Pros: simplicity. Cons: no audit trail, prone to human error.

**Decision:** terraform plan + apply on merge (basic)  
**Rationale:** Learning project with internal-only audience. Basic pipeline is sufficient. Can upgrade later if needed. Faster feedback loop aids learning.  
**Implications:** All changes go through Git + CI/CD (no local applies). No approval gates, so code review via Git is critical.  
**Alternatives Rejected:** Advanced pipeline adds overhead for a learning project. Manual applies lose reproducibility.

---

## D006: EC2 Instance Sizing — Cost-Optimized (t3.micro / t3.small)
**Date:** 2026-08-20  
**Context:** Budget constraints favor smallest viable instance sizes.

**Options Considered:**
- **t3.micro (1 vCPU, 1 GB RAM):** Cheapest — Pros: minimal cost. Cons: tight resource constraints, slow for learning.
- **t3.small (2 vCPU, 2 GB RAM):** Balanced — Pros: enough headroom, still cheap. Cons: slightly higher cost.
- **t3.medium (2 vCPU, 4 GB RAM):** Standard — Pros: comfortable, reliable. Cons: higher cost (~2x micro).

**Decision:** t3.micro for workers; t3.small for control plane  
**Rationale:** Cost is primary goal. Control plane needs slightly more resources (etcd, API server); workers can be minimal. t3.micro is borderline; may need adjustment based on actual usage.  
**Implications:** Cluster may be slow or hit resource limits under load. Acceptable for demo/learning. May need to scale up if performance issues arise.  
**Alternatives Rejected:** t3.medium exceeds cost goals. All t3.small is safer but higher cost.

---

## D007: Out of Scope — Logging, RBAC, App Deployment
**Date:** 2026-08-20  
**Context:** Define explicit boundaries to keep scope manageable.

**Decision:** 
- **Logging:** Out of scope. (ELK, CloudWatch, etc. can be added later.)
- **RBAC:** Out of scope. (Basic Kubernetes RBAC will be minimal; production RBAC policies deferred.)
- **App Deployment:** Out of scope. (Apps deployed from their own repos via sdd, not this repo.)

**Rationale:** Learning project needs clear boundaries. These are significant topics on their own and would expand scope significantly.  
**Implications:** This repo is cluster provisioning only. Apps assume a running, healthy cluster but handle their own deployment.

---

**Document Created:** 2026-08-20  
**Status:** Active  
**Total Decisions:** 7 (D001-D007)