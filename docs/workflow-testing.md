# Workflow Testing and Validation Guide

**Purpose**: Test and validate the destroy pipeline before using it in production

**Last Updated**: 2025-08-25

## Testing Prerequisites

### Environment Setup

- [ ] **GitHub Repository Access**
  - Write access to the repository
  - Ability to trigger workflows
  - Access to workflow logs

- [ ] **AWS Permissions**
  - Valid AWS credentials via OIDC
  - IAM role with destruction permissions
  - S3 state bucket access

- [ ] **Dev Environment**
  - Dev environment deployed and running
  - Resources tagged with `Environment=dev`
  - Terraform state accessible

### Test Environment Considerations

⚠️ **IMPORTANT**: These tests will actually destroy resources!
- Use a test dev environment if available
- Ensure no active work depends on the environment
- Have a recovery plan ready
- Notify team before testing

## Test Scenarios

### Test 1: Basic Workflow Execution

**Objective**: Verify the workflow runs successfully from start to finish

**Steps**:
1. Navigate to Actions tab in GitHub
2. Select "Destroy Dev Environment" workflow
3. Click "Run workflow"
4. Select environment: `dev`
5. Type confirmation: `destroy`
6. Click "Run workflow"

**Expected Results**:
- [ ] Workflow starts successfully
- [ ] All steps execute without errors
- [ ] Dev environment resources are destroyed
- [ ] Artifacts are generated
- [ ] Workflow completes with "success" status

**Validation**:
```bash
# Verify no resources remain
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"
```

### Test 2: Input Validation

**Objective**: Verify input validation prevents invalid executions

**Test 2a: Invalid Environment**
1. Start workflow
2. Select environment: `prod` (if available) or invalid option
3. Type confirmation: `destroy`

**Expected Results**:
- [ ] Workflow fails at "Validate Input" step
- [ ] Error message: "Only 'dev' environment is supported"
- [ ] No resources are destroyed

**Test 2b: Invalid Confirmation**
1. Start workflow
2. Select environment: `dev`
3. Type confirmation: `DESTROY` (wrong case)

**Expected Results**:
- [ ] Workflow fails at "Validate Input" step
- [ ] Error message: "Confirmation must be exactly 'destroy'"
- [ ] No resources are destroyed

**Test 2c: Empty Confirmation**
1. Start workflow
2. Select environment: `dev`
3. Leave confirmation empty

**Expected Results**:
- [ ] Workflow fails at "Validate Input" step
- [ ] Error message about required confirmation
- [ ] No resources are destroyed

### Test 3: Permission Validation

**Objective**: Verify permission checking works correctly

**Prerequisites**: Temporarily restrict IAM permissions

**Steps**:
1. Remove a key permission from IAM role (e.g., `ec2:*`)
2. Run the workflow with valid inputs
3. Observe permission validation step

**Expected Results**:
- [ ] Workflow fails at permission validation
- [ ] Clear error message about missing permissions
- [ ] No destruction occurs

**Cleanup**: Restore IAM permissions after test

### Test 4: Dry Run Mode

**Objective**: Test dry-run functionality without actual destruction

**Steps**:
1. Deploy a fresh dev environment
2. Modify workflow to use dry-run mode (or use local script)
3. Run with dry-run flag

**Expected Results**:
- [ ] Plan is generated
- [ ] Resources are listed
- [ ] No actual destruction occurs
- [ ] Report shows "Dry Run" status

**Local Test**:
```bash
./scripts/destroy-dev.sh dev destroy true
```

### Test 5: Error Handling

**Objective**: Verify error handling for various failure scenarios

**Test 5a: State Lock**
1. Run `terraform apply` in another terminal
2. Try to run destroy workflow
3. Observe lock handling

**Expected Results**:
- [ ] Workflow detects state lock
- [ ] Appropriate error message
- [ ] No corruption occurs

**Test 5b: Missing Resources**
1. Manually delete some resources
2. Run destroy workflow
3. Observe handling of missing resources

**Expected Results**:
- [ ] Workflow continues with remaining resources
- [ ] Reports missing resources
- [ ] Completes successfully

### Test 6: Artifact Generation

**Objective**: Verify all expected artifacts are generated

**Steps**:
1. Run successful destruction
2. Download all artifacts
3. Verify artifact contents

**Expected Artifacts**:
- [ ] `terraform-state-dev-{run_number}`
  - `terraform.tfstate`
  - `final_state.json`
  - `destroy.plan`
- [ ] `inventory-dev-{timestamp}`
  - Resource inventory files
  - Terraform state export
- [ ] `destruction_report.md`
  - Complete destruction report

**Validation**:
```bash
# Check artifact contents
tar -tzf terraform-state-dev-*.tar.gz
cat destruction_report.md
```

## Validation Scripts

### Pre-Test Validation Script

```bash
#!/bin/bash
# pre-test-validation.sh

echo "=== Pre-Test Validation ==="

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS credentials not configured"
    exit 1
fi
echo "✅ AWS credentials configured"

# Check dev environment exists
if ! aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev" --query "Reservations[*].Instances[*].InstanceId" --output text | grep -q "i-"; then
    echo "❌ No dev environment instances found"
    exit 1
fi
echo "✅ Dev environment found"

# Check Terraform state
cd src/terraform/environments/dev
if ! terraform state list &>/dev/null; then
    echo "❌ Terraform state not accessible"
    exit 1
fi
echo "✅ Terraform state accessible"

# Count resources
resource_count=$(terraform state list | wc -l)
echo "✅ Found $resource_count resources in state"

echo "=== Pre-Test Complete ==="
```

### Post-Test Validation Script

```bash
#!/bin/bash
# post-test-validation.sh

echo "=== Post-Test Validation ==="

# Check no instances remain
instance_count=$(aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev" --query "Reservations[*].Instances[*].InstanceId" --output text | wc -w)
if [ "$instance_count" -eq 0 ]; then
    echo "✅ No EC2 instances remaining"
else
    echo "❌ $instance_count instances still exist"
fi

# Check no VPCs remain
vpc_count=$(aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev" --query "Vpcs[*].VpcId" --output text | wc -w)
if [ "$vpc_count" -eq 0 ]; then
    echo "✅ No VPCs remaining"
else
    echo "❌ $vpc_count VPCs still exist"
fi

# Check Terraform state
cd src/terraform/environments/dev
state_resources=$(terraform state list 2>/dev/null | wc -l)
if [ "$state_resources" -eq 0 ]; then
    echo "✅ No resources in Terraform state"
else
    echo "⚠️  $state_resources resources still in state"
fi

echo "=== Post-Test Complete ==="
```

## Performance Testing

### Test 7: Large Environment

**Objective**: Test performance with larger number of resources

**Setup**:
- Deploy a larger dev environment (if possible)
- Include multiple instances, volumes, and networking

**Metrics to Collect**:
- [ ] Total workflow duration
- [ ] Time per phase (plan, destroy, verify)
- [ ] Memory usage of runner
- [ ] API call counts

**Expected Performance**:
- Total time: < 30 minutes
- Plan generation: < 5 minutes
- Destruction: < 20 minutes
- Verification: < 5 minutes

### Test 8: Concurrent Operations

**Objective**: Test behavior with concurrent AWS operations

**Setup**:
- Start other AWS operations during destruction
- Monitor for conflicts or race conditions

**Expected Results**:
- [ ] No resource conflicts
- [ ] Proper error handling
- [ ] Consistent final state

## Security Testing

### Test 9: Unauthorized Access

**Objective**: Verify unauthorized users cannot trigger destruction

**Setup**:
- Use account without write access
- Attempt to trigger workflow

**Expected Results**:
- [ ] Workflow cannot be triggered
- [ ] Access denied error
- [ ] No impact on infrastructure

### Test 10: Cross-Environment Access

**Objective**: Verify workflow cannot affect other environments

**Setup**:
- Modify workflow to target prod (temporarily)
- Run with valid inputs

**Expected Results**:
- [ ] Input validation blocks non-dev environments
- [ ] No impact on prod environment
- [ ] Clear error message

## Regression Testing

### Test 11: Repeated Execution

**Objective**: Test running workflow on already destroyed environment

**Steps**:
1. Destroy dev environment
2. Run destroy workflow again
3. Observe behavior

**Expected Results**:
- [ ] Workflow handles empty state gracefully
- [ ] Reports no resources to destroy
- [ ] Completes successfully

### Test 12: Partial Recovery

**Objective**: Test recovery from partial destruction

**Setup**:
- Interrupt destruction midway
- Run workflow again

**Expected Results**:
- [ ] Completes remaining destruction
- [ ] Handles partial state correctly
- [ ] No resource duplication

## Test Documentation

### Test Report Template

```markdown
# Test Execution Report

**Date**: [Date]
**Tester**: [Name]
**Environment**: [dev/test]

## Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| Basic Workflow | ✅/❌ | [Notes] |
| Input Validation | ✅/❌ | [Notes] |
| Permission Validation | ✅/❌ | [Notes] |
| Dry Run Mode | ✅/❌ | [Notes] |
| Error Handling | ✅/❌ | [Notes] |
| Artifact Generation | ✅/❌ | [Notes] |
| Performance | ✅/❌ | [Duration] |
| Security | ✅/❌ | [Notes] |

## Issues Found

1. [Issue description]
   - Severity: [High/Medium/Low]
   - Steps to reproduce
   - Expected vs actual

## Recommendations

1. [Recommendation 1]
2. [Recommendation 2]

## Sign-off

**Tested by**: [Name]  
**Date**: [Date]  
**Approved**: [Yes/No]
```

## Continuous Testing

### Automated Checks

Consider adding these automated checks:
- Workflow syntax validation
- Script syntax checking
- Permission validation
- Resource count monitoring

### Monitoring

Set up alerts for:
- Workflow failures
- Unexpected cost increases
- Orphaned resources
- Security events

## Troubleshooting Test Failures

### Common Issues

1. **Workflow doesn't start**
   - Check file syntax
   - Verify GitHub Actions permissions
   - Check YAML formatting

2. **Permission errors**
   - Verify OIDC configuration
   - Check IAM role policies
   - Validate AWS account ID

3. **Resource not found**
   - Check environment tags
   - Verify Terraform state
   - Confirm resource names

4. **Timeout errors**
   - Check resource count
   - Verify AWS rate limits
   - Monitor runner performance

### Debug Mode

Enable debug logging by adding to workflow:
```yaml
env:
  TF_LOG: DEBUG
  ACTIONS_STEP_DEBUG: true
```

## Test Sign-off

Before production use:
- [ ] All tests passed
- [ ] Issues resolved
- [ ] Documentation updated
- [ ] Team trained
- [ ] Rollback plan ready
- [ ] Monitoring configured