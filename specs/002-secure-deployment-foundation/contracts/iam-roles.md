# IAM Roles Contract

**Purpose**: Define the interface and contract for IAM roles used in secure deployments

## Role Interface Contract

### Required Role Naming Convention

All IAM roles MUST follow the naming pattern:
```
terraform-{environment}-role
```

Where `{environment}` is one of: `dev`, `prod`

### Terraform Data Source Integration

Roles are referenced in Terraform using data sources:

```hcl
data "aws_iam_role" "terraform_role" {
  name = "terraform-${var.environment}-role"
}

resource "aws_iam_role_policy" "terraform_permissions" {
  name = "terraform-permissions"
  role = data.aws_iam_role.terraform_role.id
  
  policy = jsonencode({
    # Environment-specific permissions
  })
}
```

**Requirements**:
- Roles MUST exist before Terraform apply
- Role naming MUST follow the convention above
- Terraform only manages policy attachments, not the role itself
- Manual role creation MUST include proper OIDC trust relationship

### Required Trust Policy

All roles MUST have the following trust policy structure:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::{account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:{github_org}/*:ref:refs/heads/{branch}"
        }
      }
    }
  ]
}
```

### Required Session Tagging

All roles MUST require session tagging:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::{account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "aws:RequestTag/GitHubRepo": "${github_repo}",
          "aws:RequestTag/Environment": "${environment}",
          "aws:RequestTag/Workflow": "${workflow_name}"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:{github_org}/*:ref:refs/heads/*"
        }
      }
    }
  ]
}
```

## Environment-Specific Role Contracts

### Development Role (terraform-dev-role)

**Purpose**: Full access to development environment resources

**Required Permissions**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "vpc:*",
        "s3:*",
        "iam:*",
        "dynamodb:*",
        "cloudformation:*",
        "route53:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Constraints**:
- Can only access development AWS account
- Can only access specified regions
- Full permissions for rapid iteration

### Production Role (terraform-prod-role)

**Purpose**: Highly restricted access to production environment

**Required Permissions**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "vpc:Describe*",
        "s3:Get*",
        "s3:List*",
        "iam:Get*",
        "iam:List*",
        "dynamodb:Describe*",
        "dynamodb:Get*",
        "cloudformation:Describe*",
        "cloudformation:Get*",
        "route53:Get*",
        "route53:List*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "vpc:CreateTags",
        "vpc:DeleteTags"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Constraints**:
- Read-only by default
- Can only modify tags
- Requires manual approval for any changes
- All actions logged and monitored

## Role Validation Contract

### Required Validation Rules

1. **Trust Policy Validation**
   - Must have OIDC provider as principal
   - Must have correct audience condition
   - Must have repository condition

2. **Permission Validation**
   - Must follow least-privilege principle
   - Must not have wildcard permissions (except where explicitly allowed)
   - Must have region constraints

3. **Session Validation**
   - Must require session tagging
   - Must have MFA conditions (if applicable)
   - Must have session duration limits

### Validation Implementation

```bash
#!/bin/bash
# Role validation script

validate_role() {
    local role_name=$1
    local environment=$2
    
    # Check trust policy
    local trust_policy=$(aws iam get-role-policy --role-name $role_name --policy-name TrustPolicy)
    
    # Validate OIDC provider
    if ! echo $trust_policy | grep -q "token.actions.githubusercontent.com"; then
        echo "ERROR: Missing OIDC provider in trust policy"
        return 1
    fi
    
    # Validate permissions
    local permissions=$(aws iam simulate-principal-policy \
        --policy-source-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$role_name \
        --action-names "*" \
        --resource-arns "*")
    
    # Check for overly permissive policies
    if echo $permissions | grep -q "\"Effect\": \"Allow\",.*\"Action\": \"\\*\""; then
        echo "WARNING: Overly permissive policy detected"
    fi
    
    return 0
}
```

## Role Lifecycle Contract

### Required Role Management Process

**Note**: IAM roles are manually created in AWS Management Console by security team and referenced as data sources in Terraform.

1. **Manual Role Creation** (Security Team)
   - Create OIDC Provider (if not exists)
   - Create IAM Role with trust policy
   - Configure session tagging and conditions
2. **Terraform Integration**
   - Reference role using `data "aws_iam_role"`
   - Attach environment-specific policies
   - Validate policy attachments
3. **Validation Process**
   - Verify role exists and is accessible
   - Test policy attachments
   - Validate role assumption via GitHub Actions
4. **Documentation**
   - Document role naming convention
   - Document required permissions per environment

### Required Role Update Process

1. **Create New Policy Version**
2. **Test New Configuration**
3. **Update Role Policy**
4. **Validate Changes**
5. **Monitor for Issues**
6. **Rollback if Necessary**

### Required Role Deletion Process

1. **Remove from Workflows**
2. **Detach All Policies**
3. **Delete Role**
4. **Clean Up Resources**
5. **Update Documentation**

## Monitoring Contract

### Required Monitoring Metrics

1. **Role Usage**
   - Role assumption count
   - Session duration
   - Failed assumptions

2. **Permission Usage**
   - API calls by role
   - Denied requests
   - High-risk actions

3. **Security Events**
   - Unauthorized access attempts
   - Privilege escalation attempts
   - Policy violations

### Monitoring Implementation

```json
{
  "AlarmConfigurations": [
    {
      "AlarmName": "terraform-role-assumption-failure",
      "MetricName": "AssumeRoleSuccessCount",
      "Threshold": 0,
      "ComparisonOperator": "LessThanThreshold",
      "EvaluationPeriods": 1
    },
    {
      "AlarmName": "terraform-role-high-privilege-usage",
      "MetricName": "HighPrivilegeAPICallCount",
      "Threshold": 10,
      "ComparisonOperator": "GreaterThanThreshold",
      "EvaluationPeriods": 5
    }
  ]
}
```