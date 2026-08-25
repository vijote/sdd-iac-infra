# Implementation Plan: Destroy Pipeline

**Branch**: `004-destroy-pipeline` | **Date**: 2025-08-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-destroy-pipeline/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Create a GitHub Actions workflow that manually destroys the dev environment AWS infrastructure using `terraform destroy` with safety confirmations, dry-run capabilities, and comprehensive logging. The pipeline will provide a manual trigger mechanism, require explicit confirmation before destruction, and generate pre/post destruction reports.

## Technical Context

**Language/Version**: YAML (GitHub Actions), Shell Script

**Primary Dependencies**: GitHub Actions, Terraform CLI, AWS CLI, jq

**Storage**: N/A (workflow orchestrates destruction of existing resources)

**Testing**: GitHub Actions workflow testing, manual validation

**Target Platform**: GitHub Actions runners (ubuntu-latest)

**Project Type**: CI/CD pipeline / Infrastructure automation

**Performance Goals**: Complete dev environment destruction within 10 minutes

**Constraints**: Must respect AWS rate limits, complete within GitHub Actions timeout (6 hours), must not destroy S3 state bucket

**Scale/Scope**: Destroys all dev environment resources (EC2, VPC, networking, Kubernetes)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I (IaC First) ✓
- Pipeline is defined as code in GitHub Actions YAML
- All destruction operations are version-controlled and reviewable
- No manual AWS console operations
- **Design Confirmation**: Workflow contract enforces IaC approach

### Principle II (Terraform Source of Truth) ✓
- Uses `terraform destroy` as the primary destruction mechanism
- Respects Terraform state management with backup strategies
- Does not circumvent Terraform's resource tracking
- **Design Confirmation**: State backup and archival policies defined

### Principle III (Declarative Over Imperative) ✓
- Pipeline declares intent (destroy dev environment) rather than step-by-step commands
- Uses Terraform's declarative destruction planning
- **Design Confirmation**: Plan-first approach with saved plan file

### Principle IV (Minimal, Learnable, Cost-Optimized) ✓
- Simple, focused pipeline for single purpose
- Direct cost control through complete resource termination
- No unnecessary complexity
- **Design Confirmation**: Limited to dev environment only, no scheduling or cost reporting

### Principle V (Kubernetes as Platform) ✓
- Destroys Kubernetes cluster but doesn't manage applications
- Maintains separation of concerns
- **Design Confirmation**: Pipeline destroys infrastructure, not applications

### Principle VI (Security Defaults) ✓
- Uses existing OIDC integration for AWS authentication
- Validates permissions before destruction
- Includes safety checkpoints and confirmations
- **Design Confirmation**: Multi-layer safety with explicit confirmations

### Principle VII (Documentation is Executable Proof) ✓
- Pipeline serves as executable documentation
- All steps are visible and auditable
- Generates logs and reports
- **Design Confirmation**: Comprehensive reporting and audit trail defined

### Development Constraints ✓
- Scope: Limited to dev environment destruction only
- Cost: Reduces costs to near-zero (except S3 state)
- Code Quality: Uses standard GitHub Actions practices
- **Design Confirmation**: All constraints respected in design

### Manual Validation Philosophy ✓
- Infrastructure validated on AWS directly
- Manual confirmation required before destruction
- No pre-deployment testing gates needed
- **Design Confirmation**: Manual trigger with confirmation workflow

### Infrastructure Governance ✓
- Code review required for pipeline changes
- Manual approval via workflow dispatch
- Audit trail in GitHub Actions logs
- **Design Confirmation**: 90-day audit retention with state backups

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
.github/
└── workflows/
    └── destroy-dev-environment.yml    # Main destruction pipeline

src/terraform/environments/dev/
├── main.tf                            # Existing dev environment config
├── terraform.tfvars                   # Existing dev variables
├── backend.tf                         # Existing state configuration
└── provider.tf                        # Existing AWS provider

scripts/
├── destroy-dev.sh                     # Helper script for destruction logic
├── generate-inventory.sh              # Script to list resources before destruction
└── validate-permissions.sh            # Script to check user permissions
```

**Structure Decision**: Using GitHub Actions workflow for CI/CD integration with existing Terraform structure. The pipeline will be added to `.github/workflows/` to integrate with the repository's existing CI/CD. Helper scripts in `scripts/` provide reusable logic for resource inventory, permission validation, and destruction orchestration.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitution violations. The design follows all principles and constraints.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | - | - |
