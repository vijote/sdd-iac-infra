# Research: Application Deployment Pipeline

**Date**: 2026-08-27  
**Feature**: Application Deployment Pipeline  
**Phase**: 0 - Research & Decision Making

## Research Tasks & Findings

### 1. Existing GitHub Workflows Analysis

**Current Workflows Found:**
- `terraform-apply.yml` - Applies Terraform infrastructure
- `terraform-plan.yml` - Plans Terraform changes
- `terraform-destroy.yml` - Destroys infrastructure
- `destroy-dev-environment.yml` - Destroys dev environment

**Key Findings:**
- Workflows use OIDC for AWS authentication ✓
- Proper environment separation (dev/prod) ✓
- Terraform state management in S3 ✓
- No application-specific deployment logic ✗
- Missing health checks and validation ✗

**Decision**: Create new workflow specifically for application deployment that leverages existing authentication and state management patterns.

### 2. Spec 005 Implementation Review

**Spec 005 Components:**
- Terraform module: `src/terraform/modules/application-deployment/`
- Environment configs: `src/terraform/environments/{dev,prod}/`
- Deployment scripts: `scripts/{deploy,validate,cleanup}-apps.sh`
- Kubernetes manifests for all applications

**Key Findings:**
- Infrastructure is ready ✓
- Manual deployment scripts exist ✓
- No CI/CD integration ✗
- Missing automated triggers ✗

**Decision**: Integrate existing Terraform module and scripts into GitHub Actions workflow.

### 3. Pipeline Architecture Decision

**Options Considered:**
1. **Single Workflow Approach**: One workflow for all deployment types
2. **Multi-Workflow Approach**: Separate workflows for infrastructure and applications
3. **Monorepo Approach**: Combined infrastructure and application deployment

**Decision**: **Single Workflow Approach** with environment-specific jobs
- Simplifies maintenance
- Clear separation of concerns
- Reuses existing authentication
- Easier to debug and monitor

### 4. Required GitHub Secrets and Variables

**Existing Repository Variables (Reuse Required):**
- `AWS_BOOTSTRAP_ROLE` - OIDC role for AWS access
- `AWS_TERRAFORM_ROLE` - OIDC role for Terraform operations
- `STATE_BUCKET_NAME` - S3 bucket for Terraform state
- `AWS_ACCOUNT_ID` - AWS account identifier
- `AWS_TERRAFORM_ROLE_NAME` - Terraform role name

**Additional Secrets Needed:**
- `KUBE_CONFIG` - Kubernetes configuration
- `NOTIFICATION_WEBHOOK` - For deployment notifications
- `SLACK_TOKEN` - If using Slack for notifications

**Environment Variables Pattern:**
The pipeline must follow the same pattern as existing workflows:
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

**Pipeline-Specific Variables:**
- `ENVIRONMENT` - Target environment (dev/prod)
- `DEPLOYMENT_ID` - Unique deployment identifier
- `ROLLBACK_ENABLED` - Enable/disable rollback

### 5. Integration Points Analysis

**Spec 003 (Kubernetes Cluster):**
- Cluster endpoint and configuration
- Node access and networking
- Storage classes and resource limits

**Spec 005 (Application Infrastructure):**
- Terraform module for applications
- Kubernetes manifests
- Environment configurations

**Spec 007 (Build-time Secrets)** - *To be renumbered to 007*
- AWS Secrets Manager integration
- Secure credential handling
- Environment-specific secrets

**Spec 008 (Ingress Controller)** - *To be renumbered to 008*
- External access configuration
- SSL/TLS certificate management
- Routing rules

### 6. Deployment Strategy Research

**Rolling Update Strategy:**
- Supported by Kubernetes Deployments ✓
- Zero-downtime deployments ✓
- Automatic rollback on failure ✓

**Blue-Green Strategy:**
- Requires double resources ✗
- More complex implementation ✗
- Not in scope for current requirements ✗

**Canary Strategy:**
- Advanced traffic splitting ✗
- Complex monitoring requirements ✗
- Future consideration ✓

**Decision**: Use **Rolling Update** strategy with automatic rollback.

### 7. Health Check Implementation

**Kubernetes Native Health Checks:**
- Liveness probes: Container restart
- Readiness probes: Traffic routing
- Startup probes: Application startup

**Custom Health Checks:**
- Application-specific endpoints
- Database connectivity
- Inter-service communication

**Decision**: Combine Kubernetes native probes with custom validation scripts.

### 8. Rollback Mechanism

**Automatic Rollback Triggers:**
- Health check failures
- Deployment timeout
- Resource limit exceeded
- Validation script failures

**Manual Rollback:**
- Workflow dispatch trigger
- Previous deployment selection
- Rollback validation

**Implementation**: Use Kubernetes deployment rollback with Terraform state management.

### 9. Environment Protection

**Development Environment:**
- Automatic deployment on push
- No approval required
- Full access for developers

**Production Environment:**
- Manual trigger only
- Approval workflow required
- Restricted access

**Implementation**: Use GitHub Environments with protection rules.

### 10. Monitoring and Logging

**GitHub Actions Logging:**
- Step-by-step execution logs
- Artifact storage for logs
- Workflow run history

**Additional Monitoring:**
- Deployment metrics
- Success/failure rates
- Rollback frequency

**Decision**: Leverage GitHub Actions logging with custom metrics collection.

## Technical Decisions Made

### 1. Workflow Structure
```yaml
# Single workflow with environment-specific jobs
name: Application Deployment
on:
  push:
    branches: [main]  # Auto-deploy to dev
  workflow_dispatch:  # Manual deploy to any environment
```

### 2. Deployment Order
1. Infrastructure validation (Terraform plan)
2. Infrastructure deployment (Terraform apply)
3. Application deployment (kubectl apply)
4. Health checks and validation
5. Rollback on failure

### 3. Security Model
- Use existing OIDC authentication
- Environment-specific secrets
- Minimal privilege principle
- Audit logging for all actions

### 4. Error Handling
- Retry logic for transient failures
- Immediate rollback on critical failures
- Detailed error reporting
- Manual intervention procedures

## Risks and Mitigations

### Technical Risks
1. **Pipeline Timeout**: 30-minute limit
   - Mitigation: Optimize deployment steps, parallel execution
   
2. **Resource Conflicts**: Concurrent deployments
   - Mitigation: Deployment locks, queue management
   
3. **Secrets Exposure**: Plain text credentials
   - Mitigation: GitHub secrets, OIDC tokens

### Operational Risks
1. **Rollback Failures**: Incomplete rollback
   - Mitigation: Pre-deployment validation, test rollback procedures
   
2. **Environment Drift**: Configuration differences
   - Mitigation: Infrastructure as Code, regular validation

## Next Steps

1. Create GitHub Actions workflow
2. Set up environment configurations
3. Implement deployment scripts
4. Add health checks and validation
5. Test rollback mechanisms
6. Document procedures

## Resources Referenced

- GitHub Actions Documentation
- Kubernetes Deployment Strategies
- Terraform Best Practices
- AWS EKS Deployment Patterns
- CI/CD Pipeline Design Patterns