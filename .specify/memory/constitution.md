<!--
Sync Impact Report:
- Version change: 1.0.0 → 2.0.0 (major amendment - removal of testing/validation requirements)
- Modified principles: Removed testing & validation constraints, removed quality gates
- Removed sections: Testing & Validation, Quality Gates
- Added sections: Manual Validation Philosophy
- Rationale: User wants manual AWS validation only, no upfront testing requirements
-->

# SDD-Infra Constitution

## Core Principles

### I. Infrastructure as Code (IAC) First
Every piece of infrastructure is declared in code. No manual AWS console clicks. Everything is version-controlled, reviewable, and reproducible. Code is the single source of truth; any manual changes are considered technical debt.

### II. Terraform is the Source of Truth
All AWS resources, IAM policies, networking, and compute provisioning are defined in Terraform. Terraform state is sacred; backups are maintained. Configuration drift is forbidden—any divergence between code and live infrastructure is a bug.

### III. Declarative Over Imperative
We describe *what* the infrastructure should be, not *how* to build it step-by-step. Terraform plans are reviewed before apply; changes are deliberate and auditable. No surprise infrastructure modifications.

### IV. Minimal, Learnable, Cost-Optimized
This is a learning project with tight budget constraints. Complexity is justified and documented. Every architectural choice trades off against cost, performance, and understandability. When in doubt, choose the simpler path.

### V. Kubernetes as a Platform, Not a Target
Kubernetes is the container orchestration platform. This repo provisions the cluster and foundational infrastructure; applications are deployed separately from their own repos. Clear separation of concerns between cluster and apps.

### VI. Security Defaults, Not Afterthought
IAM roles are least-privilege. Secrets are never in code; AWS Secrets Manager is mandatory. Inter-node communication is encrypted (Flannel VXLAN). VPC security groups restrict traffic. RBAC is minimal but foundational. Security reviews required for any changes.

### VII. Documentation is Executable Proof
Every infrastructure decision is documented in the Decision Log. Every deployment step is in code (cloud-init, Terraform provisioners). Runbooks exist before incidents happen. The Specification is the contract; Terraform is the implementation.

---

## Development Constraints

### Scope Management
- **No creeping features.** In/out-of-scope is locked in the Specification. Changes require decision log amendment and team agreement.
- **Cost ceiling: $50/month.** Any change that breaches this budget is flagged and requires justification.

### Code Quality Standards
- **All Terraform must be validated:** `terraform fmt`, `terraform validate`, `terraform plan` before apply.
- **Modularity:** Terraform code is organized by concern (VPC, EC2, K8s, secrets, etc.), not by layer.
- **No hardcoding:** All variables and sensitive data are injected via environment variables.
- **State management:** Terraform state is backed up; remote state (S3) is optional but recommended.
- **Readability first:** Code is self-documenting; comments explain *why*, not *what*.

---

## Manual Validation Philosophy

### AWS-First Validation
- **Infrastructure is validated on AWS directly.** No pre-deployment testing or validation gates.
- **If something breaks, requirements emerge.** New requirements are brought forward only when failures occur.
- **No upfront success criteria.** Success is determined by infrastructure functioning as needed in practice.
- **Manual verification is sufficient.** AWS console and manual checks are the validation method.

### Issue-Driven Requirements
- **Requirements emerge from failures.** When something breaks on AWS, that becomes a new requirement.
- **No speculative requirements.** We don't plan for hypothetical issues.
- **Reactive, not proactive.** Fix what breaks, don't prevent what might break.

---

## Infrastructure Governance

### Deployment Process
1. **Code Review:** All Terraform changes go through Git; peer review mandatory.
2. **Automated Validation:** CI/CD runs `terraform plan`; output is visible in PR.
3. **Manual Approval:** `terraform apply` requires explicit approval (via Git merge, no auto-apply).
4. **Audit Trail:** All changes are tracked in Git history with clear commit messages.
5. **Rollback Plan:** If deployment fails, documented rollback procedure is executed.

### Change Management
- **Major changes** (cluster topology, networking, IAM) require decision log update and team sign-off.
- **Minor changes** (instance tags, variable defaults) can be approved with code review only.
- **Breaking changes** (changes incompatible with running apps) are banned without 2-week warning and migration plan.

### Decision Log Amendments
Any change to infrastructure scope or principle requires a new Decision Log entry (D008, D009, etc.). Amendments are dated and linked to the PR that implemented them. The Decision Log is append-only; superseded decisions are marked as such but not deleted.

---

## Acceptable Technologies

### Required
- **Terraform 1.0+:** Infrastructure provisioning.
- **kubeadm:** Kubernetes bootstrap.
- **Flannel:** Pod networking.
- **nginx-ingress:** Ingress controller.
- **AWS Secrets Manager:** Secret storage.
- **Route53:** DNS.

### Allowed (May be used if justified)
- **CloudFormation:** Only for resources not easily managed via Terraform.
- **Ansible:** Only for node configuration if kubeadm becomes insufficient.
- **Helm:** Only for deploying nginx-ingress; otherwise prefer raw K8s manifests.

### Forbidden
- **Managed Kubernetes (EKS, AKS):** Defeats the learning goal.
- **Complex monitoring stacks (Prometheus, ELK):** Out of scope; future work.
- **Service mesh (Istio, Linkerd):** Out of scope; future work.
- **GitOps tools (ArgoCD, Flux):** Out of scope; apps deploy separately.

---

## Documentation Standards

### Decision Log
- **When:** Logged as decisions are made, not retroactively.
- **Format:** Follows the Decision Log template in `.coda/docs/DECISION_LOG.md`.
- **Audience:** Team members, future maintainers, onboarding engineers.
- **Review:** Not formally reviewed; captures real-time thinking.

### Specification
- **When:** Written once, after decisions are locked in.
- **Format:** Follows the Specification template; includes architecture, requirements.
- **Audience:** Stakeholders, team, external reviewers.
- **Review:** Formally reviewed and signed off before implementation.

### Runbooks
- **How to deploy:** Step-by-step Terraform commands.
- **How to debug:** Common failures, diagnostic steps, recovery procedures.
- **How to scale:** Manual steps to add/remove nodes; future auto-scaling is out of scope.
- **How to rotate secrets:** Process for updating AWS Secrets Manager without downtime.

### Code Comments
- **Why, not what:** Comments explain design decisions, not obvious code.
- **Edge cases:** Comments highlight non-obvious behavior and gotchas.
- **Links:** Comments reference Decision Log entries (e.g., "See D001: Pod Networking Choice").

---

## Known Limitations & Future Work

### Deliberately Out of Scope (In This Constitution)
- **Multi-Region:** Single region only.
- **High Availability:** Single control plane (not HA).
- **Cluster Autoscaling:** Manual scaling only.
- **Disaster Recovery:** No etcd backup/restore procedures.
- **Logging & Monitoring:** Deferred to Phase 2.
- **Advanced Networking:** Network policies, service mesh, etc.
- **Automated Testing:** Manual validation only.

### Acceptable Workarounds
- **Control plane failure:** Cluster is lost; re-provision from code. Acceptable for learning; not for production.
- **Node resource exhaustion:** t3.micro may be tight; document issues; upgrade to t3.small as needed.
- **kubeadm bootstrap timeout:** Retry cloud-init; document common failure modes.

---

## Governance & Amendment Process

### Constitution Supersedes All
This Constitution is the law of the land. All decisions, code reviews, and deployments must comply. If a decision conflicts with the Constitution, the Constitution wins.

### Amending This Constitution
- **Minor amendments** (clarifications, typo fixes): Requires PR with code review approval.
- **Major amendments** (new principles, new constraints, scope changes): Requires team decision, Decision Log entry, and full PR review.
- **All amendments are dated:** See `**Last Amended**` below.

### Conflicts & Disputes
If two principles conflict, the earlier-numbered principle takes precedence. If ambiguous, escalate to team for clarification. Document the resolution in a Decision Log entry.

---

**Version**: 2.0.0 | **Ratified**: 2026-08-20 | **Last Amended**: 2026-08-23