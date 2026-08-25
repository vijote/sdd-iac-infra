# Quick Start Guide - Destroy Pipeline

**Feature**: 004-destroy-pipeline  
**Date**: 2025-08-25

---

## Overview

This guide provides step-by-step instructions for using the destroy pipeline to safely terminate the dev environment AWS infrastructure. The pipeline includes safety mechanisms, resource inventory, and comprehensive reporting.

## Prerequisites

### Required Permissions
- GitHub repository write access
- Valid AWS credentials via OIDC integration
- IAM role with destruction permissions for dev environment
- Terraform state access (S3 bucket permissions)

### Environment Requirements
- Dev environment must be deployed and managed by Terraform
- Terraform state must be stored in S3 with proper locking
- All resources must have Environment=dev tag (except S3 state bucket)

## Quick Start

### Step 1: Navigate to GitHub Actions

1. Go to the repository's **Actions** tab
2. Select **Destroy Dev Environment** workflow from the list
3. Click **Run workflow**

### Step 2: Configure Destruction

1. **Environment**: Select `dev` (only option available)
2. **Confirmation**: Type exactly `destroy` in the confirmation field
3. Click **Run workflow** to start the pipeline

### Step 3: Monitor Progress

The pipeline will execute these steps:
1. ✅ Validate inputs and permissions
2. 📋 Generate resource inventory
3. 🔍 Create destruction plan
4. ⚠️ Final confirmation check
5. 💥 Execute destruction
6. 📊 Generate final report
7. 💾 Backup Terraform state

### Step 4: Review Results

1. Check the **Summary** tab for:
   - Number of resources destroyed
   - Any failures or warnings
   - Links to detailed reports

2. Download artifacts:
   - `terraform-state-dev-{run_number}`: State backup
   - `inventory-dev-{timestamp}`: Resource inventory
   - `destruction_report.md`: Final report

## Detailed Validation Scenarios

### Scenario 1: Successful Destruction

**Expected Outcome**:
- All dev environment resources terminated
- S3 state bucket preserved
- Monthly costs reduced to ~$0.50 (state storage only)

**Verification Steps**:
1. Check AWS Console → EC2 Instances (should be 0)
2. Check AWS Console → VPC (dev VPC should be gone)
3. Check AWS Cost Explorer (dev costs should drop to near zero)

### Scenario 2: Partial Destruction

**Symptoms**:
- Pipeline shows "Failed" status
- Some resources remain (usually security groups with dependencies)

**Recovery Steps**:
1. Download destruction report
2. Check failed resources list
3. Manually clean up remaining resources in AWS Console
4. Verify no orphaned EBS volumes remain

### Scenario 3: Accidental Trigger

**Prevention**:
- Must type "destroy" exactly
- Only dev environment can be targeted
- Multiple confirmation steps

**If Cancelled**:
- Pipeline stops before any destruction
- No resources are affected
- Safe to re-trigger if needed

## Troubleshooting

### Common Issues

#### Issue: "Confirmation must be exactly 'destroy'"
**Solution**: Type `destroy` (lowercase, no quotes) in the confirmation field

#### Issue: "Only 'dev' environment is supported"
**Solution**: Ensure you selected "dev" from the environment dropdown

#### Issue: "Permission denied" errors
**Solution**: 
1. Check OIDC role configuration
2. Verify IAM role has destruction permissions
3. Ensure S3 state bucket access

#### Issue: "State lock" errors
**Solution**:
1. Check for other running Terraform operations
2. Use `terraform force-unlock` if necessary
3. Contact repository maintainers if stuck

### Debug Mode

To enable additional logging:
1. Add `DEBUG=true` environment variable in workflow
2. Check workflow logs for detailed output
3. Review Terraform plan output carefully

## Safety Checklist

Before triggering destruction, verify:

- [ ] You have authority to destroy dev environment
- [ ] No active work depends on dev environment
- [ ] Important data has been backed up
- [ ] Team has been notified of planned destruction
- [ ] You understand this action is irreversible

After destruction:
- [ ] Verify costs have dropped as expected
- [ ] Check for any orphaned resources
- [ ] Save destruction report for audit
- [ ] Update team on completion status

## Recovery Procedures

### If You Need to Recreate Dev Environment

1. Go to the dev environment deployment workflow
2. Run the deployment pipeline
3. Verify all resources are recreated
4. Test applications and services

### If State Backup is Needed

1. Download the state backup artifact
2. Extract `terraform.tfstate` file
3. Place in `src/terraform/environments/dev/`
4. Use `terraform state list` to verify

## Cost Monitoring

### Post-Destruction Verification

1. **AWS Cost Explorer**:
   - Filter by Environment=dev tag
   - Check daily costs after destruction
   - Verify charges drop to baseline

2. **Trusted Advisor**:
   - Check for underutilized resources
   - Look for orphaned EBS volumes
   - Verify no unexpected charges

3. **Billing Alerts**:
   - Monitor for any dev environment charges
   - Set up alerts for unexpected costs

## Contact and Support

### For Issues With:
- **Pipeline failures**: Create GitHub issue
- **Permission problems**: Contact repository maintainers
- **Cost concerns**: Check AWS billing console
- **Emergency recovery**: Contact infrastructure team

### Useful Links
- [Repository Main Page]({{ repository_url }})
- [Terraform Documentation](https://www.terraform.io/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## FAQ

**Q: Can I destroy the production environment?**  
A: No, this pipeline only supports the dev environment.

**Q: Will the S3 state bucket be destroyed?**  
A: No, the state bucket is explicitly excluded from destruction.

**Q: How long does destruction take?**  
A: Usually 5-10 minutes, depending on the number of resources.

**Q: Can I cancel after starting?**  
A: Yes, you can cancel during the confirmation phase, but not after destruction begins.

**Q: What happens if destruction fails?**  
A: The pipeline reports what was destroyed and what failed, allowing manual cleanup.

**Q: Is there a cost for running the pipeline?**  
A: GitHub Actions free tier covers typical usage; no additional cost expected.