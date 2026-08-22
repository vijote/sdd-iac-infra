# Data Model: Secure Deployment Foundation

**Created**: 2025-08-22  
**Purpose**: Define entities and their relationships for the secure deployment system

## Core Entities

### GitHub Actions Workflow

**Attributes**:
- `name`: Workflow identifier
- `on`: Trigger events (pull_request, push, workflow_dispatch)
- `jobs`: Collection of job definitions
- `permissions`: GitHub token permissions
- `environment`: Target deployment environment

**Relationships**:
- Uses → IAM Role (via OIDC)
- Executes → Terraform Commands
- Produces → Deployment Logs

### IAM Role

**Attributes**:
- `name`: Role name (e.g., `terraform-dev-role`)
- `assume_role_policy`: OIDC trust relationship
- `managed_policies`: Attached AWS managed policies
- `inline_policies`: Custom permission policies
- `tags`: Resource tags for identification

**Validation Rules**:
- Must have OIDC trust relationship
- Must follow least-privilege principle
- Must be environment-specific
- Must have session tagging enabled

**Relationships**:
- Trusted by → GitHub OIDC Provider
- Has → IAM Policies
- Used by → GitHub Actions Workflows

### IAM Policy

**Attributes**:
- `name`: Policy name
- `statement`: Policy statements with actions, resources, effects
- `version`: Policy version (always "2012-10-17")

**Validation Rules**:
- Must specify resource ARNs
- Must use specific actions (not "*")
- Must include condition keys for environment isolation

### Terraform State

**Attributes**:
- `bucket`: S3 bucket name
- `key`: State file path
- `region`: AWS region
- `encrypt`: Encryption flag (always true)
- `dynamodb_table`: Lock table name

**Validation Rules**:
- Bucket must have versioning enabled
- Bucket must have encryption enabled
- DynamoDB table must have primary key "LockID"

### Environment Configuration

**Attributes**:
- `name`: Environment name (dev, staging, prod)
- `aws_account_id`: Target AWS account
- `aws_region`: Target AWS region
- `terraform_backend`: Backend configuration
- `iam_role_arn`: Role to assume for deployments

**Validation Rules**:
- Must have unique AWS account per environment
- Must have appropriate IAM role
- Must have backend configuration

## State Transitions

### Deployment Workflow States

1. **Triggered** → Workflow started by event
2. **Authenticating** → OIDC token exchange
3. **Planning** → Terraform plan execution
4. **Approval** → Manual approval (if required)
5. **Applying** → Terraform apply execution
6. **Completed** → Deployment finished

### IAM Role Session States

1. **Requested** → GitHub requests OIDC token
2. **Validated** → AWS validates OIDC token
3. **Assumed** → Role assumed with session credentials
4. **Expired** → Session expires after 1 hour

## Data Flow

### Deployment Process Flow

```
GitHub Event → Workflow Trigger → OIDC Authentication → 
IAM Role Assumption → Terraform Init → Terraform Plan → 
[Manual Approval] → Terraform Apply → State Update → 
Logging & Monitoring
```

### State Management Flow

```
Terraform Operation → State Lock Check → 
Lock Acquired → State Read/Write → Lock Release → 
State Backup (if applicable)
```

## Security Model

### Trust Boundaries

1. **GitHub ↔ AWS**: OIDC trust relationship
2. **Environment Isolation**: Separate IAM roles per environment
3. **Permission Boundaries**: Scoped IAM policies
4. **State Isolation**: Separate state files per environment

### Access Control Matrix

| Entity | Dev | Staging | Prod |
|--------|-----|---------|------|
| terraform-dev-role | Full | Read | None |
| terraform-staging-role | Read | Full | Read |
| terraform-prod-role | None | Read | Full |

## Configuration Schema

### GitHub Workflow Schema

```yaml
name: string
on:
  pull_request:
    branches: [string]
  push:
    branches: [string]
  workflow_dispatch:
    inputs: object
permissions:
  id-token: string
  contents: string
  pull-requests: string
jobs:
  job_name:
    runs-on: string
    environment: string
    steps: [step_definition]
```

### IAM Role Trust Policy Schema

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::account:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:org:repo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## Validation Rules Summary

### Workflow Validation
- Must have appropriate permissions set
- Must use OIDC authentication
- Must have environment-specific configurations

### IAM Role Validation
- Must have valid trust relationship
- Must have least-privilege policies
- Must have session tagging

### State Configuration Validation
- Must use encrypted S3 bucket
- Must have DynamoDB locking enabled
- Must have versioning enabled

### Environment Validation
- Must have unique account mapping
- Must have appropriate role mapping
- Must have backend configuration