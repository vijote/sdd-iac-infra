# Scaffolding Decision Log

**Project:** sdd-infra  
**Phase:** Phase 1 (Foundation) — Three Scaffolding Specs  
**Date:** 2026-08-20  

---

## Overview

This decision log captures the refinement of the first scaffolding phase: breaking down the foundational infrastructure into three incremental, testable specs that can be built and validated separately before moving to AWS proper.

---

## D_S001: Scope of Scaffolding Phase — Three Specs vs. Monolithic

**Date:** 2026-08-20  
**Context:** User requested clarity on "first scaffolding spec" and asked how many specs should cover the foundation. Initial spec was monolithic (all in one), but incremental approach offers better testing and clarity.

**Options Considered:**
- **Option A (Monolithic):** One spec covering VPC, IAM, EC2, and kubeadm bootstrap all together. Pros: single deliverable, clear completion. Cons: large scope, harder to test incrementally, risk of cascading failures.
- **Option B (Three Specs):** Separate specs for Networking (VPC/SGs), IAM (roles/policies), and Compute (EC2/kubeadm). Pros: incremental validation, clear dependencies, easier rollback/fixes. Cons: three deliverables, more coordination.
- **Option C (Five Specs):** Further breakdown (VPC, SGs, IAM roles, IAM policies, EC2). Pros: ultra-granular. Cons: overkill, too many sequential builds.

**Decision:** Three Specs (Option B)  
**Rationale:** 
- Networking (Spec 001) has no dependencies; can be tested first.
- IAM (Spec 002) depends on nothing; can be tested in isolation.
- Compute (Spec 003) depends on both, but combines EC2 + kubeadm for cohesion.
- Three specs align with Phase 1 timeline (Week 1-2) and are manageable for MVP.
- Each spec has clear success criteria and can be validated independently before moving to Phase 2.

**Implications:**
- Terraform modules must be composable (each spec's module can be deployed alone or together).
- Testing plan must cover unit (terraform validate) and integration (deploy to ministack/AWS) for each spec.
- Deployment order is strict: 001 → 002 → 003 (though 001 & 002 are independent and can deploy in parallel).

**Alternatives Rejected:**
- Monolithic: Too risky for learning project; hard to debug cascading failures.
- Five specs: Over-engineered; IAM role + policy can stay together.

---

## D_S002: Provider Agnosticism — AWS vs. Ministack in Code

**Date:** 2026-08-20  
**Context:** User requested ministack testing before real AWS. Question: should Terraform be provider-agnostic (same code, different configs) or separate implementations?

**Options Considered:**
- **Option A (Separate Implementations):** Write Terraform for AWS in `environments/aws/`, write separate Terraform for ministack in `environments/ministack/`. Pros: each can be optimized for its provider. Cons: code duplication, maintenance burden.
- **Option B (Provider-Agnostic Modules):** Write core modules that don't hardcode provider (AWS/ministack agnostic); provider-specific configs in `environments/aws/terraform.tfvars` vs. `environments/ministack/terraform.tfvars`. Pros: DRY, single source of truth for logic. Cons: harder to leverage provider-specific features.
- **Option C (Hybrid):** Core modules are provider-agnostic; provider-specific resources (e.g., IAM) in separate provider-specific modules. Pros: balance. Cons: complexity.

**Decision:** Provider-Agnostic Modules (Option B)  
**Rationale:**
- Learning project benefits from understanding patterns that work across providers.
- Terraform variables can swap CIDR blocks, instance types, etc., per environment.
- Ministack likely doesn't support all AWS features (IAM, Route53, Secrets Manager); can be addressed with `count` or `create_*` variables.
- Single module reduces maintenance burden as code evolves.

**Implications:**
- Modules use `variable` defaults for AWS; `environments/ministack/terraform.tfvars` overrides for ministack.
- Spec 002 (IAM) is AWS-specific; ministack environment can skip it or use stubs.
- Specs 001 and 003 (VPC/EC2) can be provider-agnostic via variables.
- Documentation must clarify which specs work on which provider.

**Alternatives Rejected:**
- Separate implementations: Duplicate code is technical debt.
- Hybrid: More complexity than benefit for MVP; start simple.

---

## D_S003: Testing Strategy — Unit + Integration + Cost Validation

**Date:** 2026-08-20  
**Context:** How should each spec be tested before considering it "done"?

**Options Considered:**
- **Option A (Unit Only):** `terraform validate` and `terraform plan` only; no actual deployment. Pros: fast feedback. Cons: misses real-world issues (API errors, timing, permissions).
- **Option B (Unit + Integration):** `terraform validate`, plan, deploy to ministack (or sandbox AWS), verify resources exist. Pros: catches real issues. Cons: slower, requires environment setup.
- **Option C (Unit + Integration + Cost):** Unit + Integration + manual cost calculation. Pros: comprehensive. Cons: slowest, most overhead.

**Decision:** Unit + Integration + Cost Validation (Option B/C hybrid)  
**Rationale:**
- Unit testing (validate, plan) is mandatory for all specs.
- Integration testing (deploy to ministack or AWS) is mandatory for specs that create resources (001, 003).
- Spec 002 (IAM) is AWS-specific; deploy to sandbox AWS account for integration testing.
- Cost validation is quick (manual check against AWS pricing) and crucial for $50/month constraint.

**Implications:**
- Each spec has a "Testing" section with specific commands.
- Ministack setup is prerequisite (user is responsible for this; not in scope).
- AWS sandbox account access needed for integration testing.
- Cost validation happens post-deployment (review AWS Cost Explorer).

**Alternatives Rejected:**
- Unit only: Risk of production failures discovered too late.
- Integration only: No structural validation before spending time on deployment.

---

## D_S004: Src Folder Organization — terraform/ + k8s/ + scripts/

**Date:** 2026-08-20  
**Context:** User requested "src folder with provisioning for first elements." How should the repo structure support scaffolding specs and future phases?

**Options Considered:**
- **Option A (Flat):** `src/` contains all files (Terraform, K8s manifests, scripts) with minimal organization. Pros: simple. Cons: chaos as project grows.
- **Option B (By Tool):** `src/terraform/`, `src/k8s/`, `src/scripts/`. Pros: clear separation by tool/language. Cons: requires traversal across dirs.
- **Option C (By Phase):** `src/phase-1/`, `src/phase-2/`, etc., each containing terraform, k8s, scripts. Pros: phase-aware. Cons: hard to find common code, duplication.

**Decision:** By Tool (Option B)  
**Rationale:**
- Terraform is the primary provisioning tool (all specs use it).
- K8s manifests (ingress, services) are applied after provisioning.
- Scripts (cloud-init, helpers) are embedded in Terraform or referenced separately.
- Developers familiar with each tool will look in `src/terraform/`, `src/k8s/`, etc.
- Supports parallel work on different tools.

**Structure:**
```
src/
├── terraform/
│   ├── modules/
│   │   ├── networking/
│   │   ├── iam/
│   │   ├── compute/
│   │   └── (future: ingress, secrets, etc.)
│   ├── environments/
│   │   ├── aws/
│   │   └── ministack/
│   └── shared/
│       └── versions.tf
├── k8s/
│   ├── manifests/
│   │   ├── ingress/
│   │   ├── services/
│   │   └── configmaps/
│   └── helm/
│       └── nginx-ingress-values.yaml
└── scripts/
    ├── deploy.sh
    ├── validate.sh
    └── cloud-init/
        ├── common.sh
        ├── control-plane.sh
        └── worker.sh
```

**Implications:**
- Each Terraform spec creates a module under `src/terraform/modules/`.
- Cloud-init scripts can live in `src/terraform/modules/compute/cloud-init/` or `src/scripts/cloud-init/`.
- K8s manifests (Flannel, nginx-ingress) are committed to `src/k8s/` or sourced from upstream (Flannel uses direct URLs).
- Deployment scripts coordinate `terraform apply` and `kubectl apply` in sequence.

**Alternatives Rejected:**
- Flat: Doesn't scale; becomes messy quickly.
- By Phase: Harder to find code; duplicates common modules.

---

## D_S005: Ministack Role — Local Testing Only, Not Production Target

**Date:** 2026-08-20  
**Context:** Ministack is for local testing before AWS. Should it be a first-class deployment target or a validation tool only?

**Options Considered:**
- **Option A (Validation Tool Only):** Ministack used to test Terraform patterns locally; real deployment is always AWS. Pros: clear separation. Cons: doesn't fully validate cluster bootstrap (K8s bootstrapping may differ locally).
- **Option B (First-Class Target):** Ministack is a target environment; cluster can deploy and run on ministack or AWS. Pros: full local validation. Cons: ministack may not support all AWS features (IAM, Secrets Manager, EBS).
- **Option C (Hybrid):** Test Terraform modules on ministack (VPC, EC2); test K8s bootstrap on AWS sandbox. Pros: pragmatic. Cons: split testing.

**Decision:** Validation Tool Only (Option A)  
**Rationale:**
- Ministack is local K8s; won't have AWS services (IAM, Secrets Manager, Route53).
- Real learning goal is AWS integration; ministack skips that.
- Better to test Terraform `plan` locally, deploy to AWS sandbox, verify there.
- Ministack useful for fast feedback on syntax errors, but not a deployment target.

**Implications:**
- Each spec's testing section includes: terraform validate (local) + terraform plan (local) + terraform apply (AWS sandbox).
- Ministack is optional for developers; not required for "done."
- IAM (Spec 002) won't deploy to ministack; AWS-only.
- Cost tracking happens on AWS; no ministack cost concerns.

**Alternatives Rejected:**
- First-class target: Too much effort to support both environments equally.
- Hybrid: Adds complexity without clarity; stick to one target per spec.

---

## D_S006: Ordering of Specs — 001 → 002 → 003 (Strict Dependency)

**Date:** 2026-08-20  
**Context:** Should specs be built sequentially or can they be built in parallel?

**Options Considered:**
- **Option A (Sequential):** Build Spec 001, validate, commit. Then Spec 002, validate, commit. Then Spec 003. Pros: clear, safe, easy rollback. Cons: slower (1-2 weeks).
- **Option B (Parallel):** Build all three specs simultaneously in feature branches. Pros: faster (1 week). Cons: harder to debug if something fails, integration risk.
- **Option C (Partial Parallel):** Build Specs 001 & 002 in parallel (independent); then 003 (depends on both). Pros: balance. Cons: moderate complexity.

**Decision:** Partial Parallel (Option C)  
**Rationale:**
- Spec 001 (Networking) has no dependencies; can be built and validated alone.
- Spec 002 (IAM) has no dependencies; can be built and validated alone.
- Spec 003 (Compute) depends on both 001 & 002; must come after.
- Developers can work on 001 & 002 concurrently, merge when ready.
- Spec 003 integration is straightforward (just references outputs from 001 & 002).

**Implications:**
- Git workflow: feature branches for 001 and 002, merge separately.
- Each spec's Terraform module is independently deployable via `terraform apply -target=module.X`.
- `environments/aws/main.tf` calls all modules; deployment is `terraform apply` (all at once) after all specs are ready.
- Testing checklist is per-spec: 001 tested → 002 tested → 003 tested → integration test.

**Alternatives Rejected:**
- Fully sequential: Slower than necessary; 001 & 002 are independent.
- Fully parallel: Too risky for learning project; need clear checkpoints.

---

## D_S007: Success Criteria — Per-Spec Validation + Integration Test

**Date:** 2026-08-20  
**Context:** How do we know when a spec is "done"?

**Options Considered:**
- **Option A (Code Complete):** Code is written, passes terraform validate, committed. Pros: fast. Cons: doesn't validate actual AWS resources.
- **Option B (Deployed & Validated):** Code is written, deployed to AWS, resources verified to exist. Pros: comprehensive. Cons: slower, costs money.
- **Option C (Deployed + Tested + Documented):** Code, deployment, verification, AND documentation complete (README, comments, decision log). Pros: thorough. Cons: slowest.

**Decision:** Deployed & Validated + Documentation (Option B/C hybrid)  
**Rationale:**
- Learning project must validate that infrastructure actually works.
- Each spec has explicit "Success Criteria" section listing what to verify.
- Spec is "done" when: code passes validate, deployed to AWS sandbox, resources verified, documentation complete.
- Cost is low (VPC/networking: free; IAM: free; EC2: ~$0.50 for 1-hour test).

**Implications:**
- Each spec includes a "Testing" section with concrete commands (terraform plan, AWS CLI describe, kubectl get, etc.).
- Success checklist is explicit in each spec (see "Success Criteria" sections in Specs 001-003).
- Final sign-off requires: terraform code review + AWS resource verification + documentation sign-off.

**Alternatives Rejected:**
- Code complete only: Risky; doesn't catch AWS API errors, IAM permission issues, etc.
- Documentation-heavy: Not needed for MVP; focus on working code first.

---

## Synthesis: Implementation Checklist

### Spec 001: VPC & Networking
- [ ] Terraform module created: `src/terraform/modules/networking/`
- [ ] Variables, outputs, main.tf, security_groups.tf, route_tables.tf all present
- [ ] `terraform validate` passes
- [ ] `terraform plan` reviewed and saved
- [ ] Deployed to AWS sandbox; all resources created
- [ ] VPC, subnets, security groups verified via AWS CLI
- [ ] Documentation complete (this spec, inline comments)
- [ ] **Status:** Ready for testing

### Spec 002: IAM Roles
- [ ] Terraform module created: `src/terraform/modules/iam/`
- [ ] Three roles created: control plane, worker, pod service account
- [ ] Policies written as JSON; attached to roles
- [ ] `terraform validate` passes
- [ ] `terraform plan` reviewed and saved
- [ ] Deployed to AWS sandbox; roles and policies exist
- [ ] Policy content verified (least privilege)
- [ ] Documentation complete
- [ ] **Status:** Ready for testing

### Spec 003: EC2 & kubeadm Bootstrap
- [ ] Terraform module created: `src/terraform/modules/compute/`
- [ ] Cloud-init scripts created: common.sh, control-plane.sh, worker.sh
- [ ] `terraform validate` passes
- [ ] `terraform plan` reviewed and saved
- [ ] Deployed to AWS sandbox; instances launched
- [ ] Cloud-init bootstrap completed; kubeadm initialized
- [ ] `kubectl get nodes` shows 3 nodes, all Ready
- [ ] Pod networking verified (Flannel deployed)
- [ ] Documentation complete
- [ ] **Status:** Ready for testing

### Integration Test
- [ ] All three specs deployed together
- [ ] Full cluster health verified
- [ ] Cost validated (<$50/month for Phase 1)
- [ ] kubeconfig exported and accessible locally
- [ ] **Status:** Phase 1 Foundation complete

---

## Next Steps

1. **Implement Spec 001** (Networking): Week 1
2. **Implement Spec 002** (IAM): Week 1 (parallel with 001)
3. **Implement Spec 003** (Compute): Week 2
4. **Integration Testing:** End of Week 2
5. **Document Learnings:** Update decision log with actual findings
6. **Phase 2 Planning:** Begin nginx-ingress, Route53, Secrets Manager (Week 3+)

---

**Version:** 1.0  
**Ratified:** 2026-08-20  
**Status:** Ready for implementation
