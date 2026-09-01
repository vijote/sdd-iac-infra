# 📦 Repository Structure Recommendations

> Is it normal to have everything in a single repo? And how to evolve it.

---

## What You Have: The Monorepo Pattern

```
sdd-iac-infra/
├── specs/          # product specs
├── src/terraform/  # infrastructure as code
├── scripts/        # ops scripts
├── tests/          # Go tests
└── .github/        # CI/CD pipelines
```

This is **normal and common** — especially at:
- Startups and small teams (< 20 engineers)
- Early-stage products
- Personal/learning projects
- Teams that just want to ship fast

---

## How Industry Typically Splits This

As organisations grow, a single repo fractures along these lines:

```
platform-team/
├── infra-repo/             # Terraform only (your sdd-iac-infra core)
│   ├── src/terraform/
│   └── .github/workflows/  # only infra pipelines
│
├── platform-docs/          # specs, ADRs, runbooks
│
└── platform-scripts/       # ops scripts (sometimes stays inside infra-repo)

app-team/
├── frontend-repo/          # SPA source code + Dockerfile + its own CI
├── backend-repo/           # Node.js source + Dockerfile + its own CI
└── app-deploy-repo/        # Kubernetes manifests only (GitOps target)
```

### The Most Common Splits and Why

| Split | Reason |
|-------|--------|
| **App code → separate repos** | Different teams own frontend vs backend. Different release cadences. |
| **K8s manifests → separate repo** | ArgoCD/Flux pulls from a dedicated "config repo". Infra changes do not trigger app deploys and vice versa. |
| **Specs/docs → separate repo or wiki** | Product managers and devs should not need to `git clone` infra code just to read a spec. |
| **Scripts → stays with infra repo** | Usually stays with infrastructure. Rarely split further. |

---

## The Real-World Spectrum

### 🟢 Small team / startup (your current stage)
> Everything in one repo. **Totally normal. Move fast.**

### 🟡 Mid-size (10–50 engineers)
> Infra repo + 1 repo per application + maybe a shared platform repo.
> A GitOps config repo starts to appear here.

### 🔴 Large org (50+ engineers, multiple teams)
> Polyrepo or monorepo with strict ownership boundaries (Nx, Bazel, Turborepo).
> Platform team owns infra repos. App teams own their own repos.
> Separate on-call rotations per repo boundary.

---

## What Is Unusual in Your Current Repo

Two things stand out as mixing concerns that industry typically separates:

### 1. `specs/` alongside Terraform
In industry, product specs live in **Notion, Confluence, Linear, or a dedicated `docs` repo** — not alongside Terraform files.
Engineers should not need to `git pull` infrastructure code just to read a product requirement.
Your specs are well-written, and keeping them here is fine while working solo. Move them to a wiki when a second person joins.

### 2. Application deployment manifests inside the infra repo
`src/terraform/modules/application-deployment/` contains K8s manifests for the SPA, Node.js, and MySQL workloads.
Industry standard (especially with GitOps) is a **dedicated "app deploy" or "config" repo** that ArgoCD or Flux watches continuously.

This separation cleanly enforces:
- **Who** can change infrastructure → platform team (infra repo)
- **Who** can deploy applications → app team (app deploy repo)

---

## The Golden Rule Industry Follows

> **One repo = one deployment boundary = one team's ownership.**

Your repo currently contains **two deployment boundaries** mixed together:
1. Infrastructure (VPC, EC2, Kubernetes cluster foundation)
2. Application workloads (SPA frontend, Node.js API, MySQL)

This is the main friction point you will feel the moment a second person or team joins.

---

## Practical Recommendation

The minimal split that makes this setup "industry-normal" without over-engineering:

```
sdd-iac-infra/              ← keep this (infrastructure + CI/CD)
  src/terraform/
    modules/networking/
    modules/kubernetes/
    modules/application-infrastructure/
    environments/
  scripts/
  .github/workflows/        # infra pipelines only

sdd-app/                    ← new repo (application code + deploy manifests)
  frontend/                 # SPA source code
  backend/                  # Node.js source code
  k8s/                      # manifests moved from application-deployment/
  .github/workflows/        # app CI: build image → push ECR → deploy to cluster
```

That single split — pulling application code and its K8s manifests into their own repo — immediately makes the setup resemble what a small-to-mid-size company would run in production.

### What stays where

| Content | Current location | Recommended location |
|---------|-----------------|----------------------|
| VPC, EC2, K8s cluster Terraform | `src/terraform/modules/` | ✅ Stay in `sdd-iac-infra` |
| App infra (Ingress, cert-manager, EBS CSI) | `src/terraform/modules/application-infrastructure/` | ✅ Stay in `sdd-iac-infra` |
| App workload manifests (deployments, services, PVCs) | `src/terraform/modules/application-deployment/` | 🔀 Move to `sdd-app/k8s/` |
| SPA frontend source code | (not yet in repo) | 🔀 `sdd-app/frontend/` |
| Node.js backend source code | (not yet in repo) | 🔀 `sdd-app/backend/` |
| Operational scripts | `scripts/` | ✅ Stay in `sdd-iac-infra` |
| Feature specs / docs | `specs/` and `docs/` | 🔀 Move to a wiki or `sdd-docs` repo over time |
| GitHub Actions infra workflows | `.github/workflows/` | ✅ Stay in `sdd-iac-infra` |
| GitHub Actions app workflows | (to be created in Spec 006) | 🔀 Lives in `sdd-app/.github/workflows/` |

---

## When to Actually Do This Split

You do **not** need to split today. Do it when one of these happens:

- A second engineer joins and needs to work on the application without touching infra
- You want to implement GitOps (ArgoCD/Flux watching a dedicated config repo)
- Application deployments start breaking infra CI pipelines or vice versa
- You want independent versioning and release tags for app vs infra
