# Specification: Application Deployment Pipeline

**Branch**: `006-application-deployment-pipeline` | **Date**: 2026-08-27 | **Status**: Draft

## Overview *(mandatory)*

This specification defines a CI/CD pipeline for deploying applications to the Kubernetes cluster created in Spec 003. The pipeline will automate the deployment of the demo applications (SPA frontend, NodeJS backend, MySQL) from Spec 005, providing a reliable, repeatable deployment process with proper validation, rollback capabilities, and environment management.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automated Application Deployment (Priority: P1)

As a developer, I want to automatically deploy applications to the Kubernetes cluster via CI/CD so that I can reliably deploy changes without manual intervention.

**Why this priority**: Essential for modern development practices and reducing deployment errors.

**Independent Test**: Can be fully tested by triggering the pipeline and verifying successful deployment.

**Acceptance Scenarios**:

1. **Given** I push code changes, **When** the pipeline triggers, **Then** the applications are automatically deployed to the appropriate environment
2. **Given** a deployment fails, **When** the pipeline detects the failure, **Then** it automatically rolls back to the previous version

---

### User Story 2 - Environment-Specific Deployments (Priority: P1)

As a developer, I want to deploy applications to different environments (dev, prod) so that I can test changes before production deployment.

**Why this priority**: Critical for maintaining separation between development and production.

**Independent Test**: Can be fully tested by deploying to both environments and verifying isolation.

**Acceptance Scenarios**:

1. **Given** I trigger a dev deployment, **When** the pipeline runs, **Then** only the dev environment is affected
2. **Given** I trigger a prod deployment, **When** the pipeline runs, **Then** production applications are updated with proper approvals

---

### User Story 3 - Deployment Validation and Health Checks (Priority: P2)

As a developer, I want the pipeline to validate deployments and check application health so that I can ensure only healthy deployments are promoted.

**Why this priority**: Ensures reliability and prevents broken deployments from reaching users.

**Independent Test**: Can be fully tested by deploying a broken application and verifying the pipeline catches the issue.

**Acceptance Scenarios**:

1. **Given** an application fails health checks, **When** the pipeline validates, **Then** the deployment is marked as failed and rolled back
2. **Given** all applications pass health checks, **When** the pipeline validates, **Then** the deployment is marked as successful

## Functional Requirements *(mandatory)*

### Pipeline Automation
- **FR-001**: System MUST automatically trigger on code changes to main branch
- **FR-002**: System MUST support manual pipeline triggers for specific environments
- **FR-003**: System MUST implement proper approval workflows for production deployments
- **FR-004**: System MUST provide deployment status visibility and notifications

### Deployment Process
- **FR-005**: System MUST deploy applications in the correct order (database → backend → frontend)
- **FR-006**: System MUST wait for each application to be healthy before proceeding
- **FR-007**: System MUST implement zero-downtime deployments where possible
- **FR-008**: System MUST support rollback to previous deployment versions

### Environment Management
- **FR-009**: System MUST maintain separate configurations for dev and prod environments
- **FR-010**: System MUST use appropriate resource limits for each environment
- **FR-011**: System MUST prevent cross-environment contamination
- **FR-012**: System MUST support environment-specific secrets and configurations

### Validation and Testing
- **FR-013**: System MUST validate Terraform code before applying
- **FR-014**: System MUST run application health checks after deployment
- **FR-015**: System MUST verify inter-service connectivity
- **FR-016**: System MUST check resource utilization against limits

## Technical Requirements *(mandatory)*

### GitHub Actions Workflow
- **TR-001**: Pipeline MUST be implemented as GitHub Actions workflow
- **TR-002**: Workflow MUST trigger on push to main branch
- **TR-003**: Workflow MUST support manual dispatch with environment selection
- **TR-004**: Workflow MUST use OIDC for AWS authentication
- **TR-005**: Workflow MUST implement proper secrets management
- **TR-005.1**: Workflow MUST reuse existing environment variables from repository
- **TR-005.2**: Workflow MUST use `STATE_BUCKET_NAME` variable for Terraform state bucket
- **TR-005.3**: Workflow MUST use `AWS_BOOTSTRAP_ROLE` and `AWS_TERRAFORM_ROLE` for authentication
- **TR-005.4**: Workflow MUST follow same environment variable patterns as existing workflows

### Deployment Strategy
- **TR-006**: System MUST use Terraform for infrastructure deployment
- **TR-007**: System MUST use kubectl for Kubernetes application deployment
- **TR-008**: System MUST implement rolling updates for applications
- **TR-009**: System MUST maintain deployment history for rollback

### Integration Points
- **TR-010**: System MUST integrate with Spec 003 (Kubernetes cluster)
- **TR-011**: System MUST integrate with Spec 005 (Application infrastructure)
- **TR-012**: System MUST integrate with Spec 007 (Build-time secrets)
- **TR-013**: System MUST integrate with Spec 008 (Ingress controller)

### Monitoring and Logging
- **TR-014**: System MUST log all deployment actions and decisions
- **TR-015**: System MUST provide deployment status via GitHub checks
- **TR-016**: System MUST send notifications on deployment success/failure
- **TR-017**: System MUST maintain deployment metrics and history

## Constraints & Assumptions *(mandatory)*

### Constraints
- **C-001**: Pipeline must complete within 30 minutes for full deployment
- **C-002**: Must not exceed GitHub Actions usage limits
- **C-003**: Must use existing AWS roles and permissions
- **C-004**: Must follow existing repository structure and conventions
- **C-005**: Must reuse existing GitHub repository variables and environment variables
- **C-006**: Must follow same environment variable naming patterns as existing workflows
- **C-007**: Must use existing `STATE_BUCKET_NAME` variable for Terraform state management

### Assumptions
- **A-001**: Kubernetes cluster is running and accessible
- **A-002**: Application infrastructure from Spec 005 is deployed
- **A-003**: AWS credentials and roles are properly configured
- **A-004**: Docker images for applications are available in registry
- **A-005**: Required GitHub secrets are configured

## Out of Scope *(mandatory)*

- Application source code CI/CD (build and test)
- Container image building and pushing
- Advanced deployment strategies (blue-green, canary)
- Multi-region deployments
- Application performance monitoring
- Database migration automation
- Security scanning and compliance checks

## Success Criteria *(mandatory)*

1. Pipeline successfully deploys all applications to dev environment on code push
2. Pipeline successfully deploys to prod environment with proper approvals
3. Failed deployments are automatically detected and rolled back
4. All health checks pass after successful deployment
5. Deployment completes within time constraints
6. Pipeline provides clear visibility into deployment status
7. Rollback functionality works correctly when needed

## Dependencies *(mandatory)*

- Spec 003: Kubernetes Cluster Foundation (must be completed)
- Spec 005: Application Deployment Infrastructure (must be completed)
- Spec 007: Build-time Secrets Manager (for secure credential handling)
- Spec 008: Ingress Controller Integration (for external access validation)

## Implementation Notes *(optional)*

The pipeline should be designed to be:
- **Idempotent**: Multiple runs with same inputs produce same results
- **Observable**: Clear logging and status reporting
- **Reliable**: Proper error handling and recovery
- **Secure**: Proper secrets management and access control
- **Scalable**: Can handle additional applications in the future

### Environment Variables to Reuse

The pipeline MUST reuse the following existing environment variables from repository settings:

#### Core Environment Variables
```yaml
env:
  ENVIRONMENT: ${{ github.event.inputs.environment || 'dev' }}
  AWS_REGION: us-east-1
  AWS_BOOTSTRAP_ROLE: ${{ vars.AWS_BOOTSTRAP_ROLE }}
  AWS_TERRAFORM_ROLE: ${{ vars.AWS_TERRAFORM_ROLE }}
  STATE_BUCKET_NAME: ${{ vars.STATE_BUCKET_NAME }}
  TF_VAR_aws_account_id: ${{ vars.AWS_ACCOUNT_ID }}
  TF_VAR_aws_terraform_role_name: ${{ vars.AWS_TERRAFORM_ROLE_NAME }}
  TF_VAR_aws_state_bucket_name: ${{ vars.STATE_BUCKET_NAME }}
```

#### Terraform Backend Configuration
- Use `STATE_BUCKET_NAME` for backend configuration: `terraform init -backend-config="bucket=${{ env.STATE_BUCKET_NAME }}"`
- Working directory pattern: `src/terraform/environments/${{ env.ENVIRONMENT }}`

#### Authentication Pattern
- Configure AWS credentials using existing OIDC roles
- Use role chaining for Terraform operations
- Follow same pattern as `terraform-apply.yml` and `terraform-plan.yml` workflows

### Workflow Structure Pattern
The new workflow should follow the same structure as existing workflows:
1. Same permissions block
2. Same environment variable definitions
3. Same AWS authentication steps
4. Same Terraform initialization pattern
5. Add application deployment steps after Terraform apply