# Research Findings - Destroy Pipeline

**Date**: 2025-08-25  
**Feature**: 004-destroy-pipeline  
**Research Areas**: GitHub Actions workflows, AWS inventory, Terraform state management

---

## 1. GitHub Actions Best Practices for Terraform Destruction

### Decision: Use workflow_dispatch with multi-step confirmation
**Rationale**: Provides manual control with safety mechanisms to prevent accidental destruction
**Alternatives considered**: 
- Automatic scheduled destruction (rejected - user wants manual control only)
- Simple webhook trigger (rejected - insufficient safety measures)

### Key Patterns Identified:
1. **Manual Trigger with Confirmation**
   ```yaml
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

2. **Multi-Step Safety Validation**
   - Validate confirmation input before any destructive operations
   - Use environment-specific restrictions (dev only)
   - Implement early exit with clear error messages

3. **Dry-Run Capability with Plan Output**
   - Always run `terraform plan -destroy` before actual destruction
   - Save the plan to a file for review
   - Display what will be destroyed in the workflow summary

4. **Comprehensive Error Handling**
   - Separate success and failure notification steps
   - Clear messaging about partial destruction scenarios
   - Exit with error code on failure

5. **State Backup and Archival**
   - Always backup the final state file after destruction
   - Use GitHub Actions artifacts with retention period
   - Provides audit trail and recovery capability

---

## 2. AWS Resource Inventory Generation

### Decision: Combined Terraform and AWS CLI approach
**Rationale**: Terraform provides managed resources list, AWS CLI discovers unmanaged resources
**Alternatives considered**:
- Terraform-only (rejected - misses resources not in state)
- AWS CLI-only (rejected - misses Terraform's understanding of dependencies)

### Key Techniques:

#### Terraform-Based Inventory
```bash
# Generate JSON plan of what will be destroyed
terraform plan -destroy -out=destroy.plan
terraform show -json destroy.plan > destroy_inventory.json

# Extract resource list using jq
cat destroy_inventory.json | jq '.planned_values.root_module.resources[] | {type: .type, name: .name, mode: .mode}'
```

#### AWS CLI Resource Discovery
```bash
# EC2 instances with environment tags
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --query "Reservations[*].Instances[*].{InstanceId:InstanceId,Type:InstanceType,State:State.Name,Tags:Tags}" \
  --output json

# VPC and networking resources
aws ec2 describe-vpcs \
  --filters "Name=tag:Environment,Values=dev" \
  --query "Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock,Tags:Tags}" \
  --output json
```

#### Combined Inventory Script Pattern
- Generate timestamped inventory directory
- Export Terraform state as JSON
- Query AWS for all tagged resources
- Create summary report in markdown
- Provide resource counts and identification

---

## 3. Terraform State Management During Destruction

### Decision: Multi-location backup with versioned archival
**Rationale**: Ensures recoverability and audit compliance while managing costs
**Alternatives considered**:
- Single backup location (rejected - single point of failure)
- No backup (rejected - violates audit requirements)

### Best Practices Identified:

#### Pre-Destruction Backup
```bash
# Pull state locally before destruction
terraform state pull > state-backup-$(date +%Y%m%d-%H%M%S).tfstate

# Upload to archival S3 bucket
aws s3 cp state-backup-*.tfstate s3://terraform-state-archive/dev/
```

#### State Locking Considerations
- Use native S3 locking (already configured: `use_lockfile = true`)
- Implement force-unlock procedures for stuck locks
- Monitor for abandoned locks during long operations

#### Partial Destruction Handling
- Use `terraform apply -destroy` with saved plan file
- Implement configurable retry limits (FR-015)
- Use `terraform state rm` for stuck resources
- Log all retry attempts for audit

#### Archival Policies
- Keep state files for 90 days (SC-003 requirement)
- Use S3 versioning (already enabled)
- Implement tiered archival (active → archive → backup)
- Consider lifecycle policies for cost optimization

---

## 4. Safety Mechanisms and Error Handling

### Decision: Multi-layer safety with explicit confirmations
**Rationale**: Prevents accidental destruction while maintaining usability
**Alternatives considered**:
- Single confirmation (rejected - insufficient safety)
- Time-based delays (rejected - doesn't prevent accidents)

### Safety Layers:
1. **Double Confirmation**
   - Manual workflow dispatch trigger
   - Explicit text confirmation ("destroy")
   - Environment validation (dev only)

2. **Plan-First Approach**
   - Always show what will be destroyed
   - Require plan review before execution
   - Save plan for audit purposes

3. **Permission Validation**
   - Use OIDC authentication
   - Validate IAM roles before destruction
   - Check for required permissions

4. **Clear Reporting**
   - Pre-destruction inventory
   - Post-destruction summary
   - Detailed logs and artifacts

---

## 5. Integration with Existing Infrastructure

### Current State Analysis:
- **Backend Configuration**: S3 with native locking enabled
- **OIDC Integration**: Already configured for GitHub Actions
- **Environment Structure**: Dev environment in `src/terraform/environments/dev/`
- **IAM Roles**: Manually provisioned per constitution amendment 2.1.0

### Integration Points:
1. **Reuse Existing Backend**: No changes needed to S3 state configuration
2. **Leverage OIDC**: Use existing AWS authentication setup
3. **Follow Directory Structure**: Work within existing Terraform layout
4. **Maintain Security**: Follow manual IAM role pattern

---

## 6. Cost Considerations

### Decision: Focus on complete resource termination
**Rationale**: User's primary goal is cost elimination when not using environment
**Alternatives considered**:
- Resource pausing (rejected - still incurs costs)
- Partial destruction (rejected - incomplete cost savings)

### Cost Optimization Strategies:
- Complete termination of all billable resources
- Preserve only S3 state bucket (~$0.50/month)
- Use GitHub Actions free tier for workflow execution
- Monitor post-destruction costs to verify zero charges

---

## 7. Implementation Priorities

Based on research, the implementation should focus on:

1. **Core Safety Features** (P0)
   - Manual trigger with confirmation
   - Plan-first destruction
   - State backup

2. **Essential Functionality** (P1)
   - Resource inventory generation
   - Error handling and logging
   - Post-destruction verification

3. **Enhanced Features** (P2)
   - Detailed reporting
   - Retry mechanisms
   - Advanced audit features

This research provides a solid foundation for implementing a safe, reliable, and cost-effective destroy pipeline that meets all specified requirements while following the project's constitutional principles.