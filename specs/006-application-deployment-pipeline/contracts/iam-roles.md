# IAM Roles Contract

**Purpose**: Define IAM role requirements for the Application Deployment Pipeline  
**Version**: 1.0  
**Date**: 2026-08-27

## Overview

The Application Deployment Pipeline uses existing OIDC-configured IAM roles for AWS authentication. No new IAM roles are required - the pipeline reuses the same roles as existing Terraform workflows.

## Existing Roles (Reuse Required)

### Bootstrap Role
**Variable**: `AWS_BOOTSTRAP_ROLE`  
**Purpose**: Initial AWS authentication via OIDC  
**Usage**: First step in authentication chain

#### Required Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/${AWS_TERRAFORM_ROLE}"
      ]
    }
  ]
}
```

### Terraform Execution Role
**Variable**: `AWS_TERRAFORM_ROLE`  
**Purpose**: Terraform operations and infrastructure management  
**Usage**: Target role for deployment operations

#### Required Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "elasticloadbalancing:*",
        "iam:*",
        "s3:*",
        "secretsmanager:*",
        "ssm:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Pipeline-Specific Requirements

### Additional Permissions for Terraform Role
The existing `AWS_TERRAFORM_ROLE` must support:

#### Kubernetes EKS Permissions
```json
{
  "Effect": "Allow",
  "Action": [
    "eks:DescribeCluster",
    "eks:ListClusters",
    "eks:AccessKubernetesApi"
  ],
  "Resource": "*"
}
```

#### S3 State Management
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::${STATE_BUCKET_NAME}",
    "arn:aws:s3:::${STATE_BUCKET_NAME}/*"
  ]
}
```

#### Secrets Manager Access
```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:CreateSecret",
    "secretsmanager:PutSecretValue"
  ],
  "Resource": [
    "arn:aws:secretsmanager:*:*:secret:demo-apps-*"
  ]
}
```

## OIDC Configuration

### GitHub Provider
The pipeline uses the existing GitHub OIDC provider configured for the repository.

#### Trust Relationship
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPOSITORY}:*"
        }
      }
    }
  ]
}
```

## Role Chaining

### Authentication Flow
1. GitHub Actions authenticates using OIDC
2. Assumes `AWS_BOOTSTRAP_ROLE`
3. Bootstrap role assumes `AWS_TERRAFORM_ROLE`
4. Terraform role performs deployment operations

### Implementation
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

## Security Requirements

### Least Privilege
- Roles must follow least privilege principle
- No wildcard permissions where specific resources can be identified
- Regular permission audits required

### Session Duration
- Bootstrap role: 15 minutes
- Terraform role: 1 hour
- Automatic session rotation

### Audit Logging
- All role assumptions logged
- CloudTrail enabled for all API calls
- Failed authentication attempts monitored

## Environment Separation

### Dev Environment
- Uses same roles with dev-specific resource constraints
- Resource naming includes `dev` prefix
- Separate state file in S3

### Prod Environment
- Uses same roles with prod-specific resource constraints
- Resource naming includes `prod` prefix
- Separate state file in S3
- Additional approval workflow required

## Compliance

### SOC 2 Controls
- Access control: Role-based access enforced
- Security: MFA required for role management
- Availability: Role failover procedures documented

### Best Practices
- No long-lived credentials
- Regular role rotation (quarterly)
- Permission reviews (monthly)
- Automated compliance checks

## Variables Required

### Repository Variables
- `AWS_BOOTSTRAP_ROLE`: ARN of bootstrap role
- `AWS_TERRAFORM_ROLE`: ARN of Terraform role
- `AWS_ACCOUNT_ID`: AWS account ID
- `AWS_TERRAFORM_ROLE_NAME`: Name of Terraform role

### Validation
```bash
# Validate role exists
aws iam get-role --role-name $TERRAFORM_ROLE_NAME

# Validate trust relationship
aws iam get-role-policy --role-name $TERRAFORM_ROLE_NAME --policy-name GitHubOIDC

# Test OIDC authentication
aws sts assume-role-with-web-identity \
  --role-arn $AWS_TERRAFORM_ROLE \
  --role-session-name test \
  --web-identity-token $TOKEN
```

## Troubleshooting

### Common Issues
1. **Role assumption failed**: Check trust relationship
2. **Permission denied**: Verify role permissions
3. **Token expired**: Refresh OIDC token
4. **State access denied**: Check S3 bucket permissions

### Debug Commands
```bash
# Check current caller identity
aws sts get-caller-identity

# List attached policies
aws iam list-attached-role-policies --role-name $ROLE_NAME

# Simulate principal policy
aws iam simulate-principal-policy \
  --policy-source-arn $ROLE_ARN \
  --action-names eks:DescribeCluster \
  --resource-arns $CLUSTER_ARN
```