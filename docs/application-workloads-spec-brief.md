# Agent Brief: Application Workloads Spec (SPA + Microservice + Database)

This file is a handoff brief for an agent running the speckit workflow
(`/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` →
`/speckit-implement`) in this repo. Follow the phases in order. Each phase is
intentionally small — do not skip ahead or merge phases, but carry the
decisions/outputs from each phase into the next so the thread doesn't break.

## Context the agent needs before starting

- This repo builds a self-managed Kubernetes cluster on AWS EC2 via kubeadm
  (see `specs/003-kubernetes-cluster-foundation/`). That cluster already
  exists as a Terraform module: `src/terraform/modules/kubernetes/`.
- There is a second, currently-empty module scaffold:
  `src/terraform/modules/application-deployment/` (with subfolders
  `kubernetes/ingress` and `kubernetes/secrets` already sketched but empty).
  This is the intended home for workload manifests — it is a separate layer
  from the cluster-provisioning module (different Terraform provider:
  `kubernetes`/`helm` against the cluster, not `aws` against the account).
- The next feature spec number is 005 (specs 001-004 already exist).

## Decisions already made (do not re-litigate these in clarify)

- Scope: exactly 1 SPA, 1 microservice, 1 database, all running inside the
  self-managed cluster.
- Database: self-managed **in-cluster**, deployed as a Kubernetes
  **StatefulSet** with a PVC — not an external managed service (no RDS).
- Deployment trigger (per Constitution v2.2.0, Principle V): the SPA and
  microservice are built and pushed to **Amazon ECR** from their own,
  separate app repos (no app source code lives in this repo). A push to ECR
  triggers a **GitHub Actions** workflow, owned by this repo, that applies
  the Kubernetes manifests under `application-deployment` to the cluster.
  This is push-based CD, not GitOps/pull-based reconciliation (ArgoCD/Flux
  remain out of scope per the Constitution).

## Open questions (resolve these during `/speckit-clarify`, not before)

- Storage provisioner/StorageClass: kubeadm-on-EC2 does not ship a default
  dynamic provisioner (no EBS CSI driver wired up yet). The StatefulSet's
  PVC needs *something* to bind to — this must be decided (e.g.
  local-path-provisioner, hostPath-backed PV, or add the EBS CSI driver).
- Database engine/image (e.g., Postgres, MySQL, other).
- Specifics of the ECR → GitHub Actions deploy workflow: does it update image
  tags via `kubectl set image` / Kustomize patch, or via a `terraform apply`
  of `application-deployment` with an image-tag variable? What identifies
  which ECR repo/tag maps to which workload (SPA vs. microservice)? Are
  placeholder images used for the initial spec until real app repos exist?
- Ingress/domain approach for exposing the SPA and/or microservice
  (the `application-deployment/kubernetes/ingress` scaffold suggests an
  Ingress controller is expected, but which one and what host/path rules
  is undecided).
- Namespace strategy (single namespace vs. per-component).
- Secrets management for DB credentials (the `kubernetes/secrets` scaffold
  exists but is empty — plain K8s Secrets vs. something else).

## Phases

### Phase 1 — Specify
Run `/speckit-specify` with a description covering: deploying 1 SPA, 1
microservice, and 1 self-managed database (StatefulSet) onto the existing
kubeadm cluster from spec 003, using the `application-deployment` module
layer. Include the "decisions already made" above as constraints in the
spec input so they land in the generated spec rather than being reopened.
Do not attempt to answer the "open questions" yet — let them surface as
`[NEEDS CLARIFICATION]` markers if the template supports it.

**Output to carry forward**: the new spec folder path (expected
`specs/005-*/`) and `spec.md`.

### Phase 2 — Clarify
Run `/speckit-clarify` against the Phase 1 spec. Work through the "open
questions" list above explicitly — the goal is that none of them remain
ambiguous going into planning. Update `spec.md` with the answers.

**Output to carry forward**: updated `spec.md` with clarifications resolved.

### Phase 3 — Plan
Run `/speckit-plan` against the clarified spec. The plan must respect the
existing module split (cluster provisioning vs. `application-deployment`
workload layer) rather than inventing a new structure. Reference
`src/terraform/modules/kubernetes/` as the upstream dependency (VPC/security
group outputs, kubeconfig access) that `application-deployment` will consume.

**Output to carry forward**: `plan.md`, `data-model.md`,
`research.md`/`contracts/` as generated.

### Phase 4 — Tasks
Run `/speckit-tasks` against the plan. Tasks should stay small and
independently testable (mirroring how specs 001-004 broke work into
per-component tasks), grouped roughly as: storage/provisioner setup → database
StatefulSet → microservice Deployment/Service → SPA Deployment/Service →
Ingress → secrets wiring → validation.

**Output to carry forward**: `tasks.md`.

### Phase 5 — Implement
Run `/speckit-implement` against `tasks.md`. Implement into
`src/terraform/modules/application-deployment/` (populating `main.tf`,
`variables.tf`, `outputs.tf`, and the `kubernetes/ingress` and
`kubernetes/secrets` subfolders), wiring it into the relevant environment
under `src/terraform/environments/`. Follow existing repo conventions found
in the `kubernetes` module (variable naming, tagging, README style) for
consistency.

## Notes on continuity between phases

- Do not restart context between phases — each phase's output is the next
  phase's input. If a phase is run in a fresh session, it must first read
  the previous phase's output files (`spec.md`, `plan.md`, `tasks.md`) before
  proceeding.
- If new ambiguities surface during planning or tasks that weren't caught in
  Phase 2, pause and resolve them explicitly (re-running `/speckit-clarify`
  if needed) rather than guessing.
