# SDD-Infra Documentation Index

Complete guide to all project documentation and how they relate.

---

## Core Project Documents

### 1. **SPECIFICATION.md** ⭐ START HERE
   - **What:** Complete project specification for the self-managed K8s cluster
   - **Length:** ~400 lines
   - **Location:** `architecture/SPECIFICATION.md`
   - **Contains:** Goals, scope, architecture, requirements, timeline, dependencies
   - **Use When:** You need to understand the overall project vision
   - **Key Sections:** Scope (in/out), Technical Requirements (FR + NFR), Components, Deployment Process

### 2. **DECISION_LOG.md**
   - **What:** Major architectural decisions and rationale (D001-D007)
   - **Length:** ~130 lines
   - **Location:** `decisions/DECISION_LOG.md`
   - **Decisions Made:** CNI (Flannel), Provisioning (Terraform+kubeadm), Instance Sizing (t3.small/micro), Ingress (nginx), Secrets (AWS Secrets Manager), CI/CD (basic), Out-of-Scope items
   - **Use When:** You want to understand the "why" behind choices
   - **Format:** Each decision includes Context, Options, Rationale, Implications

### 3. **CONSTITUTION.md**
   - **What:** Project principles, constraints, and governance
   - **Length:** ~184 lines
   - **Location:** `architecture/CONSTITUTION.md`
   - **Contains:** Core principles (IAC first, Terraform truth, Declarative, Cost-optimized), Development constraints, Testing standards, Quality gates
   - **Use When:** Writing code or making new decisions; this is the law of the land
   - **Key Sections:** Core Principles (I-VIII), Development Constraints, Quality Gates

---

## Phase 1: Scaffolding Specs (THIS PHASE)

### 4. **PHASE_1_SCAFFOLDING_SUMMARY.md** ⭐ READ FIRST FOR PHASE 1
   - **What:** Executive summary of the three scaffolding specs for Phase 1
   - **Length:** ~360 lines
   - **Location:** `phase1/PHASE_1_SCAFFOLDING_SUMMARY.md`
   - **Contains:** Overview of all specs, dependency graph, folder structure, timeline, testing checklist, success definition
   - **Use When:** You're about to start Phase 1 implementation
   - **Key Sections:** Specs Overview, Dependency Graph, Implementation Timeline (Week 1-2), Testing Checklist

### 5. **PHASE_1_VISUAL_GUIDE.md**
   - **What:** Visual diagrams and quick reference for Phase 1 specs
   - **Length:** ~330 lines
   - **Location:** `phase1/PHASE_1_VISUAL_GUIDE.md`
   - **Contains:** ASCII diagrams of each spec, resource naming conventions, quick command reference
   - **Use When:** You need a visual overview or quick lookup
   - **Key Sections:** Spec diagrams, three specs together, deployment flow, quick reference commands

### 6. **SCAFFOLDING_SPEC_001_NETWORKING.md** (To Build First)
   - **What:** Complete spec for VPC, subnets, security groups, route tables
   - **Length:** ~370 lines
   - **Location:** `scaffolding/SCAFFOLDING_SPEC_001_NETWORKING.md`
   - **Contains:** Scope, technical design, Terraform structure, testing strategy, success criteria
   - **Use When:** Building Spec 001 (VPC & Networking)
   - **Key Sections:** Scope (in/out), VPC Architecture, Security Group Rules, Terraform Structure, Testing, Success Criteria

### 7. **SCAFFOLDING_SPEC_002_IAM_ROLES.md** (To Build Second - Parallel)
   - **What:** Complete spec for IAM roles, policies, instance profiles
   - **Length:** ~390 lines
   - **Location:** `scaffolding/SCAFFOLDING_SPEC_002_IAM_ROLES.md`
   - **Contains:** Three roles (CP, Worker, Pod SA), trust policies, least-privilege scopes
   - **Use When:** Building Spec 002 (IAM Roles & Policies)
   - **Key Sections:** Scope, IAM Roles & Trust, Policy Structure, Terraform Structure, Testing, Success Criteria

### 8. **SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md** (To Build Third)
   - **What:** Complete spec for EC2 instances and kubeadm bootstrap
   - **Length:** ~520 lines
   - **Location:** `scaffolding/SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md`
   - **Contains:** Instance types, cloud-init scripts, K8s initialization, testing strategy
   - **Use When:** Building Spec 003 (EC2 & kubeadm Bootstrap)
   - **Key Sections:** Scope, K8s Architecture, Cloud-Init Bootstrap Flow, Terraform Structure, Cloud-Init Scripts, Testing, Success Criteria

### 9. **SCAFFOLDING_DECISION_LOG.md**
   - **What:** Refinement decisions specific to Phase 1 scaffolding
   - **Length:** ~310 lines
   - **Location:** `decisions/SCAFFOLDING_DECISION_LOG.md`
   - **Decisions:** Scope (3 specs vs 1), Provider Agnosticism, Testing Strategy, Folder Structure, Ministack Role, Spec Ordering, Success Criteria
   - **Use When:** You want to understand why Phase 1 is structured this way
   - **Key Sections:** D_S001-D_S007, Synthesis, Implementation Checklist

---

## Implementation Guides

### 10. **src/README.md** ⭐ FOR DEVELOPERS
   - **What:** Quick start guide and folder structure overview
   - **Length:** ~270 lines
   - **Contains:** Repository structure, scaffolding specs summary, deployment steps, verification steps, troubleshooting
   - **Use When:** You're starting implementation or need quick reference
   - **Key Sections:** Structure, Quick Start, Testing Strategy, Cost Tracking, Troubleshooting

---

## How to Use These Documents

### 🎯 **For Project Kickoff (Day 1)**
1. Read **SPECIFICATION.md** (understand the vision)
2. Read **CONSTITUTION.md** (understand the rules)
3. Skim **DECISION_LOG.md** (understand the choices)

### 🔨 **Before Phase 1 Implementation (Day 2-3)**
1. Read **PHASE_1_SCAFFOLDING_SUMMARY.md** (understand phase structure)
2. Skim **PHASE_1_VISUAL_GUIDE.md** (visual overview)
3. Read **SCAFFOLDING_DECISION_LOG.md** (understand phase decisions)
4. Read **src/README.md** (folder structure and quick start)

### 📝 **While Building Spec 001**
1. Use **SCAFFOLDING_SPEC_001_NETWORKING.md** as primary reference
2. Reference **PHASE_1_VISUAL_GUIDE.md** for diagrams
3. Refer back to **CONSTITUTION.md** for quality gates
4. Consult **src/README.md** for folder structure

### 📝 **While Building Spec 002**
1. Use **SCAFFOLDING_SPEC_002_IAM_ROLES.md** as primary reference
2. Follow same pattern as Spec 001

### 📝 **While Building Spec 003**
1. Use **SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md** as primary reference
2. Ensure it references outputs from Specs 001 & 002

### ✅ **After Phase 1 Complete**
1. Update **SCAFFOLDING_DECISION_LOG.md** with actual learnings
2. Document any deviations in a new decision entry (D_S008, etc.)
3. Prepare for Phase 2 (begin Networking spec: nginx-ingress, Route53)

---

## Document Dependencies & Reading Order

```
SPECIFICATION.md ──────┐
                       ├─→ CONSTITUTION.md
DECISION_LOG.md ───────┘
                       ┌─→ PHASE_1_SCAFFOLDING_SUMMARY.md ────┐
                       │                                       ├─→ src/README.md
SCAFFOLDING_*.md ──────┴─→ PHASE_1_VISUAL_GUIDE.md ──────────┘

                       └─→ SCAFFOLDING_DECISION_LOG.md

SPEC_001 ──────┐
               ├─→ SPEC_003 (depends on 001 & 002)
SPEC_002 ──────┘
```

---

## Quick Lookup

### I need to understand...

**...the overall project**
→ SPECIFICATION.md

**...why we chose this approach**
→ DECISION_LOG.md

**...the project rules & principles**
→ CONSTITUTION.md

**...Phase 1 structure & timeline**
→ PHASE_1_SCAFFOLDING_SUMMARY.md

**...visual overview of Phase 1**
→ PHASE_1_VISUAL_GUIDE.md

**...how to build Spec 001**
→ SCAFFOLDING_SPEC_001_NETWORKING.md

**...how to build Spec 002**
→ SCAFFOLDING_SPEC_002_IAM_ROLES.md

**...how to build Spec 003**
→ SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md

**...why Phase 1 is structured this way**
→ SCAFFOLDING_DECISION_LOG.md

**...where files go & how to deploy**
→ src/README.md

---

## Statistics

| Document | Lines | Size | Purpose |
|----------|-------|------|---------|
| SPECIFICATION.md | 389 | 18 KB | Project specification |
| DECISION_LOG.md | 130 | 6 KB | Major decisions |
| CONSTITUTION.md | 184 | 8 KB | Principles & governance |
| SCAFFOLDING_SPEC_001 | 370 | 13.5 KB | Spec 001: Networking |
| SCAFFOLDING_SPEC_002 | 386 | 12.2 KB | Spec 002: IAM |
| SCAFFOLDING_SPEC_003 | 516 | 16.7 KB | Spec 003: EC2 & kubeadm |
| SCAFFOLDING_DECISION_LOG | 307 | 15.6 KB | Spec decisions |
| PHASE_1_SUMMARY | 361 | 12.3 KB | Phase 1 overview |
| PHASE_1_VISUAL_GUIDE | 327 | 16.8 KB | Visual diagrams |
| src/README.md | 274 | 8.1 KB | Quick start |
| **TOTAL** | **3,143** | **127 KB** | **Complete Phase 1 Reference** |

---

## Version Control

All documents are version-controlled in Git:
- Specs are in `.coda/docs/`
- Implementation goes in `src/terraform/` and `src/scripts/`
- Updates to specs require PR review (per CONSTITUTION.md)

---

## Questions?

If you can't find an answer:
1. Check SPECIFICATION.md (scope & requirements)
2. Check CONSTITUTION.md (principles & constraints)
3. Check the relevant SCAFFOLDING_SPEC_00X (detailed design)
4. Check SCAFFOLDING_DECISION_LOG.md (why decisions were made)
5. Check src/README.md (implementation guide)

---

**Document Index Created:** 2026-08-20  
**Status:** Complete  
**Total Documentation:** 10 core documents + 1 index  
**Phase 1 Ready:** ✅ Yes
