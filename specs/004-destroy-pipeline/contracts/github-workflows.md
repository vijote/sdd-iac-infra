# GitHub Actions Workflow Contract

**Feature**: 004-destroy-pipeline  
**Date**: 2025-08-25

---

## Workflow Definition: Destroy Dev Environment

### Trigger Contract

```yaml
name: Destroy Dev Environment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment to destroy'
        required: true
        type: choice
        options:
          - dev
      confirm_destroy:
        description: 'Type "destroy" to confirm'
        required: true
        default: ''
```

**Requirements**:
- Must only support "dev" environment
- Confirmation input must exactly match "destroy"
- Workflow must be manually triggered (no automatic triggers)

### Permissions Contract

```yaml
permissions:
  id-token: write          # Required for OIDC authentication
  contents: read          # Required for repository checkout
  actions: write          # Required for workflow summaries and artifacts
```

**Requirements**:
- OIDC authentication required (no hardcoded credentials)
- Minimum permissions required
- Must be able to create artifacts and summaries

### Environment Variables Contract

```yaml
env:
  ENVIRONMENT: ${{ github.event.inputs.environment }}
  CONFIRMATION: ${{ github.event.inputs.confirm_destroy }}
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: 1.5.7
```

**Requirements**:
- Environment must come from workflow input
- Confirmation must be validated before destruction
- AWS region must be configurable

### Job Structure Contract

```yaml
jobs:
  destroy:
    runs-on: ubuntu-latest
    timeout-minutes: 600  # 10 hours max
    steps:
      - name: Checkout
      - name: Configure AWS Credentials
      - name: Setup Terraform
      - name: Validate Input
      - name: Generate Resource Inventory
      - name: Terraform Init
      - name: Terraform Plan (Destroy)
      - name: Confirm Destruction
      - name: Terraform Destroy
      - name: Generate Final Report
      - name: Upload State Backup
      - name: Cleanup on Failure
```

**Requirements**:
- Single job with sequential steps
- 10-hour timeout to handle large destructions
- Must include cleanup on failure

---

## Step Contracts

### 1. Validate Input

**Purpose**: Verify user inputs before any destructive operations

**Contract**:
```yaml
- name: Validate Input
  run: |
    # Validate environment
    if [ "${{ env.ENVIRONMENT }}" != "dev" ]; then
      echo "::error::Only 'dev' environment is supported"
      exit 1
    fi
    
    # Validate confirmation
    if [ "${{ env.CONFIRMATION }}" != "destroy" ]; then
      echo "::error::Confirmation must be exactly 'destroy'"
      exit 1
    fi
    
    echo "✅ Input validation passed"
```

**Requirements**:
- Must exit with error if environment is not "dev"
- Must exit with error if confirmation is not "destroy"
- Must provide clear error messages

### 2. Generate Resource Inventory

**Purpose**: Create inventory of resources that will be destroyed

**Contract**:
```yaml
- name: Generate Resource Inventory
  run: |
    # Create inventory directory
    INVENTORY_DIR="inventory-${{ env.ENVIRONMENT }}-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$INVENTORY_DIR"
    
    # Export Terraform state
    cd src/terraform/environments/${{ env.ENVIRONMENT }}
    terraform show -json > "../../$INVENTORY_DIR/terraform_state.json"
    
    # Generate inventory script
    # (Implementation details in generate-inventory.sh)
    
    # Save inventory to artifact
    echo "inventory_dir=$INVENTORY_DIR" >> $GITHUB_ENV
```

**Requirements**:
- Must create timestamped inventory directory
- Must export Terraform state as JSON
- Must save inventory as GitHub artifact

### 3. Terraform Plan (Destroy)

**Purpose**: Generate and review destruction plan

**Contract**:
```yaml
- name: Terraform Plan (Destroy)
  id: plan
  run: |
    cd src/terraform/environments/${{ env.ENVIRONMENT }}
    
    # Generate destroy plan
    terraform plan -destroy -out=destroy.plan
    
    # Show plan output
    terraform show -json destroy.plan > destroy_plan.json
    
    # Create summary
    echo "## 📋 Destruction Plan" >> $GITHUB_STEP_SUMMARY
    echo "Environment: ${{ env.ENVIRONMENT }}" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo '```' >> $GITHUB_STEP_SUMMARY
    terraform show destroy.plan >> $GITHUB_STEP_SUMMARY
    echo '```' >> $GITHUB_STEP_SUMMARY
```

**Requirements**:
- Must save plan to file for later use
- Must display plan in workflow summary
- Must output plan as JSON for processing

### 4. Confirm Destruction

**Purpose**: Final confirmation before executing destruction

**Contract**:
```yaml
- name: Confirm Destruction
  run: |
    echo "⚠️  WARNING: About to destroy ${{ env.ENVIRONMENT }} environment"
    echo "Resources to be destroyed:"
    terraform show -json destroy.plan | jq '.planned_values.root_module.resources | length'
    echo ""
    echo "Type 'confirm' to proceed or 'cancel' to abort:"
    
    # In GitHub Actions, we use the initial confirmation
    if [ "${{ env.CONFIRMATION }}" != "destroy" ]; then
      echo "::error::Destruction cancelled"
      exit 1
    fi
    
    echo "✅ Proceeding with destruction..."
```

**Requirements**:
- Must show clear warning
- Must display resource count
- Must use initial confirmation for final approval

### 5. Terraform Destroy

**Purpose**: Execute the actual destruction

**Contract**:
```yaml
- name: Terraform Destroy
  id: destroy
  run: |
    cd src/terraform/environments/${{ env.ENVIRONMENT }}
    
    # Execute destruction
    terraform apply -input=false -auto-approve destroy.plan
    
    # Verify destruction
    terraform show -json > final_state.json
    
    echo "✅ Destruction completed"
  continue-on-error: true
```

**Requirements**:
- Must use saved plan file
- Must continue on error for reporting
- Must save final state

### 6. Generate Final Report

**Purpose**: Create comprehensive destruction report

**Contract**:
```yaml
- name: Generate Final Report
  if: always()
  run: |
    # Determine destruction status
    if [ "${{ steps.destroy.outcome }}" == "success" ]; then
      STATUS="✅ Success"
    else
      STATUS="❌ Failed"
    fi
    
    # Create report
    cat > destruction_report.md << EOF
    # 💥 Destruction Report - ${{ env.ENVIRONMENT }}
    
    **Status**: $STATUS  
    **Requested by**: ${{ github.actor }}  
    **Started**: $(date)  
    **Pipeline**: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
    
    ## Resources Destroyed
    EOF
    
    # Add resource details from final state
    if [ -f final_state.json ]; then
      echo "Final state saved" >> destruction_report.md
    fi
    
    # Upload report as artifact
    echo "report_path=destruction_report.md" >> $GITHUB_ENV
```

**Requirements**:
- Must run regardless of success/failure
- Must include status and requester
- Must link to pipeline run

### 7. Upload State Backup

**Purpose**: Backup Terraform state for audit and recovery

**Contract**:
```yaml
- name: Upload State Backup
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: terraform-state-${{ env.ENVIRONMENT }}-${{ github.run_number }}
    path: |
      src/terraform/environments/${{ env.ENVIRONMENT }}/terraform.tfstate
      final_state.json
      destroy.plan
    retention-days: 365
```

**Requirements**:
- Must run regardless of success/failure
- Must include state file and plan
- Must retain for 365 days

---

## Error Handling Contract

### On Failure Requirements

1. **Clear Error Messages**: All failures must have descriptive error messages
2. **Partial Destruction Reporting**: Must report what was destroyed if failure occurs
3. **State Preservation**: Must preserve final state even on failure
4. **Cleanup**: Must clean up temporary files and resources
5. **Notification**: Must update GitHub status with failure

### Error Scenarios

```yaml
- name: Handle Destruction Failure
  if: steps.destroy.outcome == 'failure'
  run: |
    echo "::error::Destruction failed"
    echo "Some resources may still exist"
    echo "Please check the AWS console"
    echo "State backup has been saved"
    exit 1
```

---

## Security Contract

### Authentication Requirements

1. **OIDC Only**: No hardcoded AWS credentials
2. **Least Privilege**: IAM role must have minimum required permissions
3. **Role Validation**: Must validate role has destruction permissions
4. **Session Duration**: Must use appropriate session duration

### Permission Requirements

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "iam:PassRole",
        "kms:Decrypt",
        "kms:DescribeKey",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

**Note**: S3 bucket containing state must be excluded from destruction policies

---

## Output Contract

### Artifacts

1. **State Backup**: `terraform-state-dev-{run_number}`
   - terraform.tfstate
   - final_state.json
   - destroy.plan

2. **Resource Inventory**: `inventory-dev-{timestamp}`
   - terraform_state.json
   - aws_resources.json
   - inventory_summary.md

3. **Destruction Report**: `destruction_report.md`
   - Summary of destruction
   - List of destroyed/failed resources
   - Recommendations

### Workflow Summary

- Must include destruction plan
- Must show final status
- Must link to artifacts
- Must include resource counts

### GitHub Status

- Success: All resources destroyed
- Failure: Partial or complete failure
- Cancelled: User cancelled during confirmation