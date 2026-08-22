# Research: Secure Deployment Foundation

**Created**: 2025-08-22  
**Purpose**: Research findings for implementation decisions

## OIDC Authentication vs Service Accounts

### Decision: Use GitHub Actions OIDC Authentication

**Rationale**: 
- Eliminates need to store and rotate static AWS credentials
- Provides short-lived credentials automatically
- Integrates natively with GitHub's permission model
- Follows security best practices for CI/CD

**Alternatives Considered**:
- Static AWS access keys (rejected due to security risks)
- Self-hosted runners with IAM profiles (rejected due to complexity)
- Third-party secrets management (rejected due to cost)

## Terraform State Backend Options

### Decision: Use S3 + DynamoDB

**Rationale**:
- S3 provides durable, scalable storage for state files
- DynamoDB provides state locking to prevent corruption
- Native AWS integration with IAM roles
- Cost-effective for our scale ($50/month budget)
- Well-documented and widely adopted

**Alternatives Considered**:
- Terraform Cloud (rejected due to cost)
- Azure Blob Storage (rejected - not in AWS ecosystem)
- Local state (rejected - not suitable for team collaboration)

## IAM Role Structure

### Decision: Environment-Specific Roles

**Rationale**:
- Clear separation of concerns between environments
- Least privilege principle applied per environment
- Easy to audit and manage permissions
- Supports blast radius containment

**Role Structure**:
- `terraform-dev-role`: Full access to dev resources
- `terraform-staging-role`: Limited access to staging resources
- `terraform-prod-role`: Highly restricted access to production

## GitHub Actions Workflow Strategy

### Decision: Separate Workflows for Plan and Apply

**Rationale**:
- Clear separation of concerns
- Plan runs on PR for visibility
- Apply runs on merge for deployment
- Supports manual approval for production
- Prevents accidental deployments

**Workflow Structure**:
- `terraform-plan.yml`: Runs on PR, shows plan output
- `terraform-apply.yml`: Runs on merge to main, applies changes
- `terraform-destroy.yml`: Manual workflow for cleanup

## Cost Optimization Strategies

### Decision: Use Free Tier and Minimal Resources

**Rationale**:
- GitHub Actions: 2000 minutes/month free tier
- S3: First 5GB storage free, then $0.023/GB
- DynamoDB: 25WCUs free, then $0.00013 per request
- Well within $50/month budget

**Estimated Monthly Costs**:
- GitHub Actions: $0 (within free tier)
- S3 State Storage: ~$0.05 (100MB)
- DynamoDB Locking: ~$0.10 (light usage)
- Data Transfer: ~$0.50
- **Total**: ~$0.65/month

## Security Considerations

### OIDC Trust Relationship Configuration

**Required Configuration**:
- GitHub OIDC Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- Condition: String equals for repository and branch

### IAM Policy Scoping

**Least Privilege Approach**:
- Dev environment: Full access to VPC, EC2, S3 in dev account
- Staging: Read-only on production, full on staging
- Production: Require manual approval, minimal permissions

### Audit and Logging

**Implementation**:
- AWS CloudTrail for all API calls
- GitHub Actions logs for workflow execution
- Terraform state versioning for change tracking
- IAM role session tagging for attribution

## Testing Strategy

### Automated Testing

**Unit Tests**:
- IAM policy validation
- Terraform configuration validation
- Workflow syntax validation

**Integration Tests**:
- OIDC authentication flow
- End-to-end deployment in dev
- State locking behavior

**Security Tests**:
- Permission boundary validation
- Credential leakage detection
- Unauthorized access attempts

## Implementation Dependencies

### Prerequisites
- AWS account with appropriate permissions
- GitHub repository with appropriate settings
- Terraform 1.5+ installed locally
- AWS CLI configured for initial setup

### Order of Operations
1. Create OIDC provider in AWS
2. Create IAM roles with trust relationships
3. Configure S3 bucket and DynamoDB table
4. Set up GitHub repository secrets (if needed)
5. Create and test workflows
6. Validate end-to-end deployment

## Risk Mitigation

### Identified Risks
1. **OIDC Misconfiguration**: Mitigated by thorough testing
2. **State Corruption**: Mitigated by DynamoDB locking
3. **Permission Escalation**: Mitigated by least-privilege roles
4. **Cost Overrun**: Mitigated by monitoring and alerts

### Rollback Plan
- Keep manual deployment capability
- Maintain state backups
- Document rollback procedures
- Test rollback scenarios