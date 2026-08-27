# GitHub Actions Workflow Contract

**Purpose**: Define the interface contract for the Application Deployment Pipeline workflow  
**Version**: 1.0  
**Date**: 2026-08-27

## Workflow Interface

### Trigger Events
```yaml
on:
  push:
    branches: [main]  # Auto-deploy to dev
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'dev'
        type: choice
        options: [dev, prod]
      force_deploy:
        description: 'Force deployment even if health checks fail'
        required: false
        default: false
        type: boolean
```

### Required Permissions
```yaml
permissions:
  id-token: write          # Required for OIDC
  contents: read          # Required for checkout
  pull-requests: write    # Required for PR comments (if needed)
  actions: read           # Required for workflow status
```

### Environment Variables (Inherited)
```yaml
env:
  # Core Configuration (from repository)
  ENVIRONMENT: ${{ github.event.inputs.environment || 'dev' }}
  AWS_REGION: us-east-1
  AWS_BOOTSTRAP_ROLE: ${{ vars.AWS_BOOTSTRAP_ROLE }}
  AWS_TERRAFORM_ROLE: ${{ vars.AWS_TERRAFORM_ROLE }}
  STATE_BUCKET_NAME: ${{ vars.STATE_BUCKET_NAME }}
  TF_VAR_aws_account_id: ${{ vars.AWS_ACCOUNT_ID }}
  TF_VAR_aws_terraform_role_name: ${{ vars.AWS_TERRAFORM_ROLE_NAME }}
  TF_VAR_aws_state_bucket_name: ${{ vars.STATE_BUCKET_NAME }}
  
  # Pipeline-Specific
  DEPLOYMENT_ID: deploy-${{ github.run_number }}-${{ github.sha }}
  COMMIT_SHA: ${{ github.sha }}
  BRANCH: ${{ github.ref_name }}
```

## Job Structure

### Main Deployment Job
```yaml
jobs:
  deploy:
    name: Deploy Applications
    runs-on: ubuntu-latest
    environment: ${{ env.ENVIRONMENT }}
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        # OIDC authentication steps
      
      - name: Deploy Infrastructure
        # Terraform apply steps
      
      - name: Deploy Applications
        # kubectl apply steps
      
      - name: Validate Deployment
        # Health check steps
      
      - name: Rollback on Failure
        # Rollback steps if needed
```

### Environment-Specific Jobs
- **Development**: Automatic deployment, no approval required
- **Production**: Manual trigger only, approval required

## Outputs

### Workflow Outputs
```yaml
outputs:
  deployment_id:
    description: 'Unique deployment identifier'
    value: ${{ jobs.deploy.outputs.deployment_id }}
  environment:
    description: 'Target environment'
    value: ${{ env.ENVIRONMENT }}
  status:
    description: 'Deployment status'
    value: ${{ jobs.deploy.outputs.status }}
  service_urls:
    description: 'Deployed service URLs'
    value: ${{ jobs.deploy.outputs.service_urls }}
```

### Job Outputs
```yaml
jobs:
  deploy:
    outputs:
      deployment_id: ${{ steps.deploy.outputs.deployment_id }}
      status: ${{ steps.validate.outputs.status }}
      service_urls: ${{ steps.validate.outputs.service_urls }}
      rollback_available: ${{ steps.deploy.outputs.rollback_available }}
```

## Integration Points

### Terraform Integration
- **Working Directory**: `src/terraform/environments/${{ env.ENVIRONMENT }}`
- **State Backend**: Uses `STATE_BUCKET_NAME`
- **Variables**: Passes TF_VAR_* variables

### Kubernetes Integration
- **Kubeconfig**: From `KUBE_CONFIG` secret
- **Namespace**: `demo-apps`
- **Manifests**: From Spec 005 module

### Notification Integration
- **Success**: Sends deployment success notification
- **Failure**: Sends failure notification with rollback status
- **Webhook**: Uses `NOTIFICATION_WEBHOOK` if configured

## Error Handling

### Retry Logic
- **AWS API**: Retry with exponential backoff
- **Kubernetes API**: Retry with exponential backoff
- **Health Checks**: Retry up to 3 times with 30s intervals

### Rollback Triggers
- Health check failures
- Deployment timeout (>30 minutes)
- Resource limit exceeded
- Manual rollback trigger

## Security Requirements

### OIDC Authentication
```yaml
- name: Configure AWS Credentials (Bootstrap)
  uses: aws-actions/configure-aws-credentials@v6
  with:
    role-to-assume: ${{ env.AWS_BOOTSTRAP_ROLE }}
    aws-region: ${{ env.AWS_REGION }}

- name: Assume Terraform Target Role
  uses: aws-actions/configure-aws-credentials@v6
  with:
    role-to-assume: ${{ env.AWS_TERRAFORM_ROLE }}
    aws-region: ${{ env.AWS_REGION }}
    role-chaining: true
```

### Secrets Management
- No secrets in workflow files
- Use GitHub secrets for sensitive data
- Use repository variables for configuration
- Audit logging for all secret access

## Compliance

### Audit Requirements
- All deployment actions logged
- Rollback decisions documented
- Approval workflow for production
- Change tracking via git commit SHA

### Rate Limits
- Respect GitHub Actions usage limits
- Implement queuing for concurrent deployments
- Timeout protection (30 minutes max)

## Version Compatibility

### Minimum Requirements
- GitHub Actions: Latest
- Terraform: >= 1.0
- kubectl: >= 1.24
- AWS CLI: >= 2.0

### Tested Versions
- GitHub Actions: Current stable
- Terraform: 1.5+
- kubectl: 1.28+
- AWS CLI: 2.13+