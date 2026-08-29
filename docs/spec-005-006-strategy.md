# Spec 005-006 Application Deployment Strategy

**Created**: 2026-08-27  
**Purpose**: Defines the two-spec approach for application deployment and session management strategy  
**Status**: Ready for implementation  

## Executive Summary

Splitting application deployment into two separate specs to manage context constraints (200K limit + heavy thinking usage) and enable pragmatic, deployment-first validation approach.

## Spec Organization

### Spec 005 - Application Infrastructure Foundation
- **Module**: `src/terraform/modules/application-infrastructure/`
- **Components**:
  - EBS CSI driver setup
  - NGINX Ingress controller
  - cert-manager SSL setup
  - Storage classes and networking foundation
- **Target Size**: ~8-10K characters
- **Validation Strategy**: Deployment-first - get infrastructure running, manual verification
- **Dependencies**: Consumes outputs from `src/terraform/modules/kubernetes/`

### Spec 006 - Application Workload Deployment
- **Module**: `src/terraform/modules/application-workloads/`
- **Components**:
  - PostgreSQL StatefulSet
  - SPA and microservice deployments
  - Kustomize overlay system
  - GitHub Actions ECR workflow
  - Secrets management integration
- **Target Size**: ~10-12K characters
- **Validation Strategy**: Deployment-first - get applications running, manual debugging
- **Dependencies**: Consumes outputs from Spec 005's infrastructure module

## Session Management Strategy

### Context Management
- **Separate Sessions**: Fresh session for each spec (005 and 006)
- **Rationale**: Prevents context buildup with 200K limit and heavy thinking usage
- **Model Behavior**: Model will likely forget almost everything between sessions

### Handoff Approach
- **Memory Persistence**: Save key decisions to MEMORY.md between sessions
- **Constraint Files**: Create constraint files for each spec
- **No Dependency on Model Memory**: Explicit documentation ensures continuity

### Validation Philosophy
- **No Automated Tests**: Skip testing components per user preference
- **Manual Debugging**: "If anything fails I'll manually find it when deployed"
- **Deployment-First**: Focus on getting something deployed quickly, then iterate

## Architectural Constraints (Carried Forward)

From the grilling session, these decisions apply to both specs:

### Storage & Database
- **Storage Provisioner**: EBS CSI driver
- **Database Engine**: PostgreSQL (StatefulSet)
- **Database Service**: Headless Service for StatefulSet communication

### Organization & Networking
- **Namespace Strategy**: Single namespace for all components
- **Ingress Controller**: Community NGINX Ingress Controller
- **External Access**: Single domain with path-based routing
  - SPA: `<domain>/*` (root path)
  - API: `<domain>/api/*`
- **SSL/TLS**: cert-manager with Let's Encrypt certificates
- **Internal Communication**: 
  - SPA → Microservice: ClusterIP Service
  - Microservice → Database: Headless Service

### Deployment & Image Management
- **Deployment Trigger**: ECR push → GitHub Actions workflow → Kubernetes manifest updates
- **Update Mechanism**: Kustomize overlay patching
- **Image Mapping**: Configuration file mapping ECR repositories to Kubernetes deployments
- **Initial Validation**: Use existing community images (like Traefik) for placeholder testing

### Secrets & Security
- **Secrets Storage**: AWS Secrets Manager (per Constitution)
- **Secret Injection**: GitHub Actions workflow fetches and creates/patches Kubernetes Secrets

## Implementation Sequence

### Phase 1: Spec 005 (Infrastructure Foundation)
1. Run `/speckit-specify` with infrastructure constraints
2. Run `/speckit-clarify` to resolve infrastructure-specific questions
3. Run `/speckit-plan` for infrastructure components
4. Run `/speckit-tasks` for infrastructure implementation
5. Run `/speckit-implement` to create `application-infrastructure/` module
6. **Memory Persistence**: Save completion status to MEMORY.md
7. Deploy and manually validate infrastructure

### Phase 2: Spec 006 (Application Workloads)
1. **Start Fresh Session**: New context window
2. **Memory Recall**: Read MEMORY.md for Spec 005 completion status
3. Run `/speckit-specify` with workload constraints
4. Run `/speckit-clarify` to resolve workload-specific questions
5. Run `/speckit-plan` for application components
6. Run `/speckit-tasks` for workload implementation
7. Run `/speckit-implement` to create `application-workloads/` module
8. Deploy full application stack and debug manually

## Files to Create

### For Spec 005
- `docs/spec-005-constraints.md` (already created)
- `specs/005-application-infrastructure-foundation/` directory

### For Spec 006  
- `docs/spec-006-constraints.md` (to be created after 005)
- `specs/006-application-workload-deployment/` directory

## Constitutional Compliance

Both specs honor Constitution v2.2.0:
- **Principle V**: Kubernetes as platform, ECR-triggered deployment model
- **Principle IV**: Minimal, learnable, cost-optimized choices
- **Principle VI**: Security defaults with AWS Secrets Manager
- **Manual Validation Philosophy**: AWS-first validation, issue-driven requirements

## Next Steps

1. **Start Session 1**: Begin Spec 005 with fresh context
2. **Apply Constraints**: Use `docs/spec-005-constraints.md` as input
3. **Memory Persistence**: Save progress to MEMORY.md before session end
4. **Start Session 2**: Begin Spec 006 with fresh context, read MEMORY.md

---

*This strategy document ensures continuity across sessions while respecting context constraints and validation preferences.*