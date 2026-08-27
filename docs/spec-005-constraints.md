# Spec 005 Application Deployment - Architectural Constraints

**Created**: 2026-08-27  
**Purpose**: Defines settled architectural decisions for Application Workloads Spec (SPA + Microservice + Database)  
**Status**: Ready for speckit specification phase  

## Context

These constraints emerged from a grilling session to establish the application deployment architecture for the SDD project. They represent settled decisions that must be honored during the `/speckit-specify` phase for spec 005.

## Settled Architectural Decisions

### Storage & Database
- **Storage Provisioner**: EBS CSI driver (not local-path-provisioner)
- **Database Engine**: PostgreSQL (StatefulSet)
- **Database Service**: Headless Service for StatefulSet communication
- **Persistence**: EBS volumes via CSI driver for database data

### Organization & Networking
- **Namespace Strategy**: Single namespace for all components (SPA, microservice, database)
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
- **Update Mechanism**: Kustomize overlay patching (not kubectl set image or Terraform apply)
- **Image Mapping**: Configuration file mapping ECR repositories to Kubernetes deployments
- **Initial Validation**: Use existing community images (like Traefik) for placeholder testing

### Secrets & Security
- **Secrets Storage**: AWS Secrets Manager (per Constitution)
- **Secret Injection**: GitHub Actions workflow fetches and creates/patches Kubernetes Secrets
- **No External Secrets Operator**: Keep workflow self-contained

## Module Structure Constraints

- **Target Module**: `src/terraform/modules/application-deployment/`
- **Subfolders**: Must use existing `kubernetes/ingress` and `kubernetes/secrets` scaffolds
- **Provider Separation**: Use `kubernetes`/`helm` providers (not `aws`) against the cluster
- **Upstream Dependency**: Consumes outputs from `src/terraform/modules/kubernetes/`

## Constitutional Compliance

All decisions honor Constitution v2.2.0 principles:
- **Principle V**: Kubernetes as platform, ECR-triggered deployment model
- **Principle IV**: Minimal, learnable, cost-optimized choices
- **Principle VI**: Security defaults with AWS Secrets Manager
- **Acceptable Technologies**: Uses only required/allowed technologies (nginx-ingress, ECR, GitHub Actions)

## Open Questions for Clarify Phase

These constraints are settled. The following remain open for `/speckit-clarify`:
- Specific domain name for the application
- ECR repository naming conventions
- GitHub Actions workflow file structure
- Kustomize overlay organization
- Database configuration details (version, settings)
- Resource sizing and limits

## Next Steps

1. Run `/speckit-specify` with these constraints as input
2. Proceed to `/speckit-clarify` to resolve remaining open questions
3. Continue with `/speckit-plan`, `/speckit-tasks`, `/speckit-implement`

---

*This document represents shared understanding from architectural decision-making. Do not modify without re-running the grilling process.*