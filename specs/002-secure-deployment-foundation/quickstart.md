# Quickstart Guide: Secure Deployment Foundation

**Purpose**: End-to-end validation scenarios for secure CI/CD deployment

## Prerequisites

### Required Accounts and Access
- GitHub account with repository access
- AWS account with IAM permissions
- Terraform 1.5+ installed locally
- AWS CLI configured for initial setup

### Required Permissions
- AWS: Ability to create IAM roles, OIDC providers, S3 buckets
- GitHub: Repository admin permissions for workflows and secrets

**Note**: This implementation uses manually provisioned S3 bucket with native S3 locking (no DynamoDB table required)

## Setup Validation Scenarios

### Scenario 1: OIDC Provider Setup

**Objective**: Validate GitHub Actions can authenticate to AWS using OIDC

**Steps**:
1. Create OIDC provider in AWS:
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

2. Validate provider creation:
```bash
aws iam list-open-id-connect-providers
```

**Expected Outcome**:
- OIDC provider created successfully
- Provider ARN returned in list

**Validation Command**:
```bash
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn $(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[0].Arn' --output text)
```

### Scenario 2: IAM Role Creation

**Objective**: Validate least-privilege IAM roles for each environment

**Steps**:
1. Create trust policy file:
```bash
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[0].Arn' --output text)"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$(git config --get remote.origin.url | sed 's/.*:\/\/github.com\///' | sed 's/\.git$//'):*"
        }
      }
    }
  ]
}
EOF
```

2. Create development role:
```bash
aws iam create-role \
  --role-name terraform-dev-role \
  --assume-role-policy-document file://trust-policy.json \
  --description "Terraform deployment role for development environment"
```

3. Attach development policy:
```bash
aws iam put-role-policy \
  --role-name terraform-dev-role \
  --policy-name TerraformDevPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["ec2:*", "vpc:*", "s3:*", "iam:*", "dynamodb:*"],
        "Resource": "*"
      }
    ]
  }'
```

**Expected Outcome**:
- Role created successfully
- Policy attached without errors
- Role ARN returned

**Validation Command**:
```bash
aws iam get-role --role-name terraform-dev-role
aws iam get-role-policy --role-name terraform-dev-role --policy-name TerraformDevPolicy
```

### Scenario 3: Terraform State Backend Setup

**Objective**: Validate remote state configuration with locking

**Steps**:
1. Create S3 bucket for state:
```bash
aws s3api create-bucket \
  --bucket terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --region us-east-1
```

2. Enable versioning:
```bash
aws s3api put-bucket-versioning \
  --bucket terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --versioning-configuration Status=Enabled
```

3. Enable encryption:
```bash
aws s3api put-bucket-encryption \
  --bucket terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

4. Create DynamoDB table for locking:
```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Expected Outcome**:
- S3 bucket created with versioning and encryption
- DynamoDB table created for state locking

**Validation Command**:
```bash
aws s3api get-bucket-versioning --bucket terraform-state-$(aws sts get-caller-identity --query Account --output text)
aws dynamodb describe-table --table-name terraform-locks
```

## Deployment Validation Scenarios

### Scenario 4: GitHub Actions Workflow Setup

**Objective**: Validate workflows can authenticate and run Terraform operations

**Steps**:
1. Create `.github/workflows/terraform-plan.yml`:
```yaml
name: Terraform Plan
on:
  pull_request:
    branches: [main]
permissions:
  id-token: write
  contents: read
  pull-requests: write
jobs:
  plan:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v4
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/terraform-dev-role
          aws-region: us-east-1
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0
      - name: Terraform Init
        run: terraform init -input=false
      - name: Terraform Plan
        run: terraform plan -input=false
```

2. Create repository secrets:
   - `AWS_ACCOUNT_ID`: Your AWS account ID
   - `AWS_REGION`: Target AWS region

3. Create a pull request to trigger workflow

**Expected Outcome**:
- Workflow runs successfully
- OIDC authentication works
- Terraform plan executes without errors

**Validation Command**:
Check GitHub Actions workflow logs for successful authentication and plan execution.

### Scenario 5: End-to-End Deployment

**Objective**: Validate complete deployment pipeline from PR to production

**Steps**:
1. Create a test Terraform configuration:
```hcl
# main.tf
resource "aws_s3_bucket" "test" {
  bucket = "test-bucket-$(uuid)"
}

output "bucket_name" {
  value = aws_s3_bucket.test.id
}
```

2. Configure backend:
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "terraform-state-$(aws sts get-caller-identity --query Account --output text)"
    key    = "test/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}
```

3. Create pull request with test changes
4. Review plan output in PR comments
5. Merge pull request to trigger apply
6. Validate deployment in AWS console

**Expected Outcome**:
- Plan shows expected changes
- Apply creates resources successfully
- State file updated in S3
- Lock acquired and released properly

**Validation Command**:
```bash
# Check state file
aws s3 ls s3://terraform-state-$(aws sts get-caller-identity --query Account --output text)/test/

# Check created resource
aws s3 ls | grep test-bucket
```

## Security Validation Scenarios

### Scenario 6: Least Privilege Validation

**Objective**: Validate roles only have required permissions

**Steps**:
1. Test with development role:
```bash
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/terraform-dev-role \
  --role-session-name test-session \
  --web-identity-token $(echo "fake-token") \
  --duration-seconds 900
```

2. Test unauthorized access:
```bash
# Try to access production resources with dev role
aws s3 ls s3://production-bucket --profile assumed-role
```

**Expected Outcome**:
- Authorized actions succeed
- Unauthorized actions fail with AccessDenied
- All actions logged in CloudTrail

**Validation Command**:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity
```

### Scenario 7: Credential Validation

**Objective**: Validate no static credentials are stored

**Steps**:
1. Scan repository for secrets:
```bash
# Install trufflehog
pip install truffleHog

# Scan for secrets
trufflehog --regex --entropy=False .github/
```

2. Check workflow logs for exposed credentials:
```bash
# Check workflow runs for masked secrets
gh run list --repo $(git config --get remote.origin.url)
```

**Expected Outcome**:
- No secrets found in repository
- All credentials properly masked in logs
- Only OIDC tokens used for authentication

## Troubleshooting Validation

### Common Issues and Solutions

1. **OIDC Authentication Fails**
   - Verify OIDC provider exists
   - Check trust policy conditions
   - Validate repository URL format

2. **Role Assumption Denied**
   - Verify role policy permissions
   - Check session tagging requirements
   - Validate AWS region constraints

3. **State Lock Issues**
   - Check DynamoDB table exists
   - Verify IAM permissions for DynamoDB
   - Manually release stuck locks if needed

4. **Workflow Permissions**
   - Verify GitHub token permissions
   - Check repository secret configuration
   - Validate environment protection rules

## Success Criteria

All validation scenarios should pass:
- ✅ OIDC provider created and functional
- ✅ IAM roles created with least-privilege permissions
- ✅ Remote state backend configured with locking
- ✅ GitHub Actions workflows authenticate successfully
- ✅ End-to-end deployment pipeline functional
- ✅ Security controls validated (no static credentials)
- ✅ Monitoring and logging operational

## Next Steps

After successful validation:
1. Configure additional environments (staging, prod)
2. Set up monitoring and alerting
3. Document team onboarding process
4. Establish incident response procedures
5. Schedule regular security reviews