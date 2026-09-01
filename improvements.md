# 🔍 Anti-patterns & Improvement Opportunities

> Analysis of `sdd-iac-infra` — transitioning from a learning project to a production-aligned codebase.

---

## 🚨 Security Issues (Fix First)

### 1. SSH open to `0.0.0.0/0`
**File**: `src/terraform/modules/networking/main.tf:115-125`

```hcl
# Current — anyone on the internet can attempt SSH
cidr_blocks = ["0.0.0.0/0"]
description = "Allow SSH access from external runners"
```

**Why it is an anti-pattern**: This exposes port 22 on the control plane to the entire internet. Even with key-based auth, this is a target for brute-force and exploit scanning.

**Fix**: Restrict to your specific IP, use an AWS SSM Session Manager (already have the SSM role!), or use a bastion host. The project already attaches the SSM IAM policy to the nodes — use it and close port 22 entirely.

```hcl
# Remove the SSH rule entirely and connect via SSM:
aws ssm start-session --target <instance-id>
```

---

### 2. Kubernetes API (6443) open to `0.0.0.0/0`
**File**: `src/terraform/modules/networking/main.tf:127-137`

```hcl
cidr_blocks = ["0.0.0.0/0"]
description = "Kubernetes API server external access for kubectl"
```

**Why it is an anti-pattern**: The K8s API server exposed to the whole internet is a major attack surface. Real production clusters either use a private endpoint (VPN/bastion) or restrict access to specific CIDRs.

**Fix**: Restrict to your own IP or use AWS VPN/Direct Connect. If you need CI/CD access, use the GitHub Actions IP ranges published by GitHub.

---

### 3. Secrets passed through Terraform variables (and potentially state)
**File**: `.github/workflows/terraform-apply.yml` env vars: `TF_VAR_mysql_root_password`, `TF_VAR_jwt_secret`

**Why it is an anti-pattern**: Terraform variables passed this way get written into the `.tfstate` file in plaintext. Even though the S3 bucket is encrypted at rest, the state file is readable by anyone with S3 access.

**Fix**: Use `aws_secretsmanager_secret_version` data sources inside Terraform to read secrets directly from Secrets Manager at apply time — never pass them as variables. Or use Kubernetes external-secrets-operator at runtime instead of baking them in at apply time.

---

### 4. Build-time secret injection (Spec 006-BTS) is an anti-pattern itself
**File**: `specs/006-build-time-secrets/spec.md`

The spec proposes fetching secrets from Secrets Manager at `docker build` time and injecting them via `--build-arg`. Even with multi-stage builds, this approach risks leaking secrets into image layers and build logs.

**Fix**: Use **runtime secret injection** instead. The industry standard is:
- Kubernetes Secrets (base case)
- **External Secrets Operator** syncing from AWS Secrets Manager to K8s Secrets at runtime
- AWS SSM Parameter Store with the AWS SDK reading at app startup

This keeps secrets out of images entirely.

---

## ⚠️ Infrastructure Anti-patterns

### 5. Single control plane — SPOF
**File**: `src/terraform/modules/kubernetes/main.tf` — only one `aws_instance.control_plane`

**Why it is an anti-pattern**: If the control plane EC2 goes down, the entire cluster is unavailable. etcd (the cluster database) is also gone.

**Fix for production**: Run 3 control plane nodes with an odd number (for etcd quorum). For this project within budget, at minimum: **take periodic etcd snapshots**.

```bash
# Add this as a cron job on the control plane
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d).db
```

---

### 6. No NAT Gateway — worker nodes cannot reach the internet
**File**: `src/terraform/modules/networking/main.tf:75` — private route tables have no internet route (intentional, commented as cost optimization)

**The problem**: Worker nodes are in private subnets. Without a NAT Gateway, they cannot:
- Pull container images from Docker Hub / ECR
- Download Kubernetes updates
- Reach AWS APIs (SSM, Secrets Manager, EBS)

**How it works currently**: Workers rely on the EC2 instance profile (SSM + EBS) which goes through VPC endpoints, and image pulling likely works because nodes have outbound rules to `0.0.0.0/0` but no route to get there.

**Fix options**:
- Add a **NAT Gateway** (~$32/month — breaks budget) or
- Use **VPC Endpoints** for all AWS services (ECR, S3, SSM) — cheaper, but more setup
- Move workers to the **public subnet** temporarily (acceptable for a learning project, bad for production)

---

### 7. Control plane is in the public subnet
**File**: `src/terraform/modules/kubernetes/main.tf:111` — `subnet_id = var.subnet_ids[0]` (the public subnet)

**Why it is an anti-pattern**: In production, control planes should be in private subnets. External access to the API server should go through a load balancer or VPN, not directly to the instance.

**Fix**: Move the control plane to a private subnet + put a load balancer (ALB or NLB) in front of the API server port.

---

### 8. Private SSH key generated and stored in Terraform state
**File**: `src/terraform/modules/kubernetes/main.tf:38-46`

```hcl
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

**Why it is an anti-pattern**: The private key is written to the Terraform state file in plaintext. Anyone who can read the S3 state can SSH into your nodes.

**Fix**: Generate the key pair **outside Terraform** (e.g., `ssh-keygen` locally, or use AWS Console), then pass only the public key as a variable. Store the private key in a secrets manager or locally.

---

### 9. Flannel CNI does not support NetworkPolicies
**File**: `specs/003-kubernetes-cluster-foundation/spec.md`

**Why it matters**: Flannel provides basic pod networking but has zero support for Kubernetes `NetworkPolicy` objects. This means any pod can talk to any other pod — there is no network-level isolation.

**Fix**: Replace Flannel with **Calico** or **Cilium**. Both support NetworkPolicies and Cilium also provides eBPF-based observability. Migration is disruptive but achievable by draining nodes and re-applying.

---

## 🛠️ Operational Anti-patterns

### 10. No etcd backup
There is no mechanism for backing up etcd. Losing the control plane = losing the entire cluster state permanently.

**Fix**: Add a CronJob or systemd timer on the control plane:
```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db
aws s3 cp /tmp/etcd-backup.db s3://<state-bucket>/etcd-backups/$(date +%F).db
```

---

### 11. No observability stack
No Prometheus, Grafana, CloudWatch agent, or log aggregation. The only monitoring is manual script execution.

**Fix (incremental)**:
1. Enable **CloudWatch Agent** on EC2 (free tier friendly)
2. Add **kube-state-metrics** for cluster metrics
3. Add **Prometheus + Grafana** via Helm (Spec 005 already has Helm)

---

### 12. No pre-commit hooks
TFLint is configured (`.tflint.hcl` exists) but there are no git pre-commit hooks to enforce it. Linting only runs if someone remembers to run it manually or it catches it in CI.

**Fix**: Add a `.pre-commit-config.yaml` with `terraform fmt`, `terraform validate`, and `tflint` hooks.

---

## 🏗️ Architecture Nice-to-Haves

### 13. GitOps instead of push-based CD
The project uses push-based deployment (GitHub Actions runs `kubectl apply`). This is fine but does not align with how most production K8s environments work today.

**Industry standard**: Pull-based GitOps with **ArgoCD** or **Flux**. The cluster continuously syncs its state from Git. No kubectl in pipelines.

> Note: This is a bigger change — not worth doing unless you are moving toward a real production system.

---

### 14. No Horizontal Pod Autoscaler (HPA)
No HPA or KEDA is configured. Pods do not scale under load.

**Fix**: Add HPA resources to the application-deployment module for the Node.js backend.

---

### 15. No Pod Disruption Budgets (PDB)
Spec 006 mentions zero-downtime deployments but there are no PDB resources. During a `kubectl drain` or node replacement, all replicas of a deployment could be evicted at once.

---

### 16. No VPC Endpoints
All AWS API traffic (SSM, Secrets Manager, EBS, ECR) exits through the internet gateway. VPC Endpoints would keep this traffic private, reduce latency, and remove the NAT dependency.

---

### 17. Spec numbering gap (008 missing)
There is a jump from Spec 007 to Spec 009. No documentation explains what Spec 008 was planned to be. Minor, but confusing for onboarding.

---

### 18. Comments in Spanish mixed with English code
**File**: `src/terraform/modules/kubernetes/main.tf:48,66,88,94,100` and `application-infrastructure/main.tf:38`

```hcl
# 1. Rol de IAM para las instancias EC2 del clúster
# 2. Política para permitir guardar y leer el token de join en SSM
```

Not a functional problem, but inconsistent for a project that should be readable by collaborators of any language background. Pick one language for comments.

---

## 📋 Priority Recommendation

| Priority | Item | Effort | Impact |
|----------|------|--------|--------|
| 🔴 Now | Close SSH (0.0.0.0/0) — use SSM | Low | High |
| 🔴 Now | Restrict K8s API (6443) to known CIDRs | Low | High |
| 🔴 Now | Stop passing secrets as TF variables | Medium | High |
| 🟠 Soon | etcd backup cron job | Low | High |
| 🟠 Soon | Replace Flannel → Calico (NetworkPolicies) | Medium | Medium |
| 🟠 Soon | Fix private key in Terraform state | Medium | High |
| 🟡 Later | NAT Gateway or VPC Endpoints | Medium | Medium |
| 🟡 Later | Add CloudWatch Agent + kube-state-metrics | Medium | Medium |
| 🟡 Later | Pre-commit hooks (tflint, fmt, validate) | Low | Low |
| 🟡 Later | Pod Disruption Budgets + HPA | Low | Medium |
| 🔵 Future | Move control plane to private subnet | High | Medium |
| 🔵 Future | GitOps (ArgoCD/Flux) | High | Medium |
