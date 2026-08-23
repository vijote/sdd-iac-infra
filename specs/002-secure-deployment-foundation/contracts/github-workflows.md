# GitHub Actions Workflow Contracts

**Purpose**: Define the interface and contract for GitHub Actions workflows

## Workflow Interface Contract

### Required Workflow Triggers

All deployment workflows MUST support the following triggers:

```yaml
on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - prod
```

### Required Permissions

All workflows MUST request minimal permissions:

```yaml
permissions:
  id-token: write          # Required for OIDC
  contents: read          # Required for checkout
  pull-requests: write    # Required for PR comments
  actions: read           # Required for workflow status
```

### Required Environment Variables

All workflows MUST use the following environment variables:

| Variable | Source | Description |
|----------|--------|-------------|
| `AWS_ACCOUNT_ID` | Repository secret | Target AWS account ID |
| `AWS_REGION` | Repository secret | Target AWS region |
| `ENVIRONMENT` | Workflow input | Target environment |
| `TERRAFORM_VERSION` | Workflow constant | Terraform version to use |

### Required Job Structure

#### Plan Job Contract

```yaml
plan:
  runs-on: ubuntu-latest
  environment: ${{ inputs.environment }}
  outputs:
    plan_has_changes: ${{ steps.plan.outputs.plan_has_changes }}
    plan_exit_code: ${{ steps.plan.outputs.exitcode }}
  steps:
    - name: Checkout
      uses: actions/checkout@v4
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/terraform-${{ env.ENVIRONMENT }}-role
        aws-region: ${{ env.AWS_REGION }}
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TERRAFORM_VERSION }}
    - name: Terraform Init
      run: terraform init -input=false
    - name: Terraform Plan
      id: plan
      run: |
        terraform plan -input=false -out=tfplan
        echo "plan_has_changes=$(terraform plan -detailed-exitcode -out=tfplan && echo "true" || echo "false")" >> $GITHUB_OUTPUT
    - name: Plan Summary
      run: terraform show -json tfplan | jq -r '.planned_values'
```

#### Apply Job Contract

```yaml
apply:
  needs: plan
  if: needs.plan.outputs.plan_has_changes == 'true'
  runs-on: ubuntu-latest
  environment: 
    name: ${{ inputs.environment }}
    url: ${{ steps.deploy.outputs.outputs_url }}
  steps:
    - name: Checkout
      uses: actions/checkout@v4
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/terraform-${{ env.ENVIRONMENT }}-role
        aws-region: ${{ env.AWS_REGION }}
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TERRAFORM_VERSION }}
    - name: Terraform Init
      run: terraform init -input=false
    - name: Terraform Apply
      id: deploy
      run: terraform apply -input=false -auto-approve tfplan
```

## Error Handling Contract

### Required Error Handling

All workflows MUST handle the following error scenarios:

1. **Authentication Failure**
   - Detect failed OIDC authentication
   - Fail workflow with clear error message
   - Create GitHub issue for manual intervention

2. **Plan Failure**
   - Capture plan error output
   - Comment on PR with error details
   - Fail workflow with appropriate exit code

3. **Apply Failure**
   - Capture apply error output
   - Attempt automatic rollback if possible
   - Create incident ticket

### Error Output Format

```yaml
- name: Handle Error
  if: failure()
  run: |
    echo "::error::Deployment failed for ${{ env.ENVIRONMENT }}"
    echo "::error::Error details: ${{ steps.deploy.outputs.stderr }}"
    echo "::error::Please check the workflow logs and investigate"
    exit 1
```

## Notification Contract

### Required Notifications

Workflows MUST provide notifications for:

1. **Plan Results**
   - Comment on PR with plan summary
   - Include resource changes graph
   - Tag relevant team members

2. **Apply Results**
   - Update deployment status
   - Provide output URLs
   - Send Slack notification (if configured)

### Notification Format

```yaml
- name: Notify PR
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const output = `## Terraform Plan Results
      **Environment**: ${{ env.ENVIRONMENT }}
      **Changes**: ${{ needs.plan.outputs.plan_has_changes }}
      **Plan Output**: \`\`\`
      ${{ steps.plan.outputs.stdout }}
      \`\`\``;
      
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: output
      });
```

## Security Contract

### Required Security Measures

1. **No Secrets in Logs**
   - Mask all sensitive outputs
   - Use GitHub Actions secret filtering
   - Sanitize Terraform outputs

2. **Session Tagging**
   - Tag all AWS sessions with metadata
   - Include workflow run ID
   - Include PR number (if applicable)

3. **Audit Logging**
   - Log all role assumptions
   - Log all Terraform operations
   - Maintain audit trail for 90 days

### Security Validation

```yaml
- name: Validate Security
  run: |
    # Validate no secrets in outputs
    if terraform output -json | grep -q "AKIA\|sk.\|password\|secret"; then
      echo "::error::Secrets detected in outputs"
      exit 1
    fi
    
    # Validate session tagging
    aws sts get-caller-identity --query 'Arn' --output text
```

## Performance Contract

### Required Performance Metrics

1. **Plan Execution**
   - Must complete within 5 minutes
   - Must show progress indicators
   - Must cache Terraform providers

2. **Apply Execution**
   - Must complete within 10 minutes
   - Must provide real-time output
   - Must handle large state files efficiently

### Performance Optimization

```yaml
- name: Cache Terraform
  uses: actions/cache@v4
  with:
    path: ~/.terraform.d
    key: ${{ runner.os }}-terraform-${{ hashFiles('**/*.lock.hcl') }}
    restore-keys: |
      ${{ runner.os }}-terraform-
```