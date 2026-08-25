# Cost Verification Checklist

**Purpose**: Verify that dev environment destruction has successfully reduced AWS costs to the expected baseline

**Last Updated**: 2025-08-25

## Pre-Destruction Baseline

### Before Destroying Dev Environment

- [ ] **Document Current Monthly Costs**
  - Go to AWS Cost Explorer
  - Filter by `Environment=dev` tag
  - Note the current monthly run rate
  - Screenshot or export the cost breakdown

- [ ] **Identify Major Cost Drivers**
  - EC2 instances (type, count, hours)
  - EBS volumes (size, type)
  - Data transfer (if any)
  - Load balancers (if any)
  - Other services

- [ ] **Record Resource Counts**
  - Number of EC2 instances
  - Number and size of EBS volumes
  - Number of VPCs and subnets
  - Any other billable resources

## Immediate Post-Destruction Checks (Within 1 Hour)

### Verify Resource Termination

- [ ] **EC2 Instances**
  - Check EC2 Console: Instances should be 0
  - Verify with CLI: `aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"`
  - All instances should be in "terminated" state

- [ ] **EBS Volumes**
  - Check Volumes Console: No dev-tagged volumes
  - Verify with CLI: `aws ec2 describe-volumes --filters "Name=tag:Environment,Values=dev"`
  - Look for orphaned volumes (no instance attachment)

- [ ] **VPC Resources**
  - Check VPC Console: No dev-tagged VPCs
  - Verify subnets, gateways, NAT gateways are deleted
  - CLI: `aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"`

- [ ] **Load Balancers**
  - Check EC2 Console → Load Balancers
  - Verify no dev-tagged load balancers exist
  - CLI: `aws elbv2 describe-load-balancers`

- [ ] **Other Resources**
  - RDS instances (if any)
  - ElastiCache clusters (if any)
  - S3 buckets (except state bucket)
  - CloudFormation stacks

## Cost Verification Timeline

### 24 Hours After Destruction

- [ ] **Check Cost Explorer**
  - Daily costs should show significant drop
  - Dev environment costs should be near $0
  - Compare to pre-destruction baseline

- [ ] **Verify Billing Dashboard**
  - Current month charges
  - Forecasted monthly charges
  - Should show ~$0.50 for S3 state storage only

### 3 Days After Destruction

- [ ] **Review Cost Explorer Trends**
  - Daily cost graph should show drop to baseline
  - No unexpected cost spikes
  - Verify no orphaned resources accumulating costs

- [ ] **Check Trusted Advisor**
  - Look for "Low Utilization Amazon EC2 Instances"
  - Check for "Underutilized EBS Volumes"
  - Review "Idle Load Balancers"

### End of Month Verification

- [ ] **Final Cost Comparison**
  - Compare month-over-month costs
  - Dev environment costs should be minimal
  - Document actual savings achieved

## Detailed Cost Analysis

### Using AWS Cost Explorer

1. **Create Cost Report**:
   - Go to Cost Explorer
   - Filter by tag: `Environment=dev`
   - Group by service
   - Set date range: 7 days before/after destruction

2. **Expected Results**:
   - EC2 costs: $0
   - EBS costs: $0 (except state backup)
   - Data Transfer: $0
   - Other services: $0

3. **Acceptable Remaining Costs**:
   - S3 State Storage: ~$0.50/month
   - Data Transfer OUT: $0 (no traffic)
   - CloudWatch Logs: Minimal (if any)

### Using AWS CLI Commands

```bash
# Check current month costs by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --filter Dimensions={Key=TAG,Values=Environment=dev} \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Check daily costs for last 7 days
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "7 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --filter Dimensions={Key=TAG,Values=Environment=dev} \
  --granularity DAILY \
  --metrics BlendedCost
```

## Troubleshooting Unexpected Costs

### If Costs Remain High

1. **Check for Orphaned Resources**:
   ```bash
   # EBS volumes not attached
   aws ec2 describe-volumes --filters "Name=status,Values=available" "Name=tag:Environment,Values=dev"
   
   # Elastic IPs not released
   aws ec2 describe-addresses --filters "Name=tag:Environment,Values=dev"
   
   # NAT Gateways still running
   aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev"
   ```

2. **Verify Tag Coverage**:
   - Some resources might not have Environment=dev tag
   - Check for resources with project name tags
   - Look for resources created manually

3. **Check Other Services**:
   - CloudWatch Logs retention
   - S3 access logs
   - Config rules
   - CloudTrail logs (usually free)

### Common Orphaned Resources

1. **EBS Volumes**:
   - Detached but not deleted
   - Manual cleanup required
   - Check for snapshots

2. **Elastic IPs**:
   - Allocated but not attached
   - Incurs charges when not attached
   - Release if not needed

3. **NAT Gateways**:
   - Expensive if left running
   - Check VPC deletion status
   - Manual deletion may be required

4. **S3 Buckets**:
   - Data storage costs
   - Request costs
   - Lifecycle policies needed

## Cost Optimization Recommendations

### After Successful Destruction

1. **Set Up Billing Alerts**:
   - Create budget for dev environment
   - Alert at $10/month (should never trigger)
   - Email notifications

2. **Implement Cost Anomaly Detection**:
   - AWS Budgets anomaly detection
   - Monitor for unexpected charges
   - Daily digest emails

3. **Regular Cost Reviews**:
   - Monthly cost review
   - Check for new services
   - Verify tag compliance

### Long-Term Cost Management

1. **Tagging Strategy**:
   - Ensure all resources have Environment tag
   - Use consistent tagging
   - Automate tag enforcement

2. **Lifecycle Policies**:
   - S3 bucket lifecycle rules
   - EBS snapshot policies
   - Log retention policies

3. **Resource Cleanup Automation**:
   - Scheduled resource cleanup
   - Automated orphan detection
   - Regular resource audits

## Documentation

### Save for Audit

- [ ] **Pre-Destruction Cost Report**
  - Screenshot of Cost Explorer
  - Export CSV data
  - Save with destruction artifacts

- [ ] **Post-Destruction Verification**
  - Cost comparison report
  - Resource cleanup confirmation
  - Savings calculation

- [ ] **Monthly Cost Tracking**
  - Ongoing monthly reports
  - Year-over-year comparison
  - Budget vs actual

## Contacts

### For Cost Issues
- **Finance Team**: For billing questions
- **Infrastructure Team**: For resource cleanup
- **AWS Support**: For billing disputes

### Useful Links
- [AWS Cost Explorer](https://console.aws.amazon.com/cost-management/)
- [AWS Billing Dashboard](https://console.aws.amazon.com/billing/)
- [Trusted Advisor](https://console.aws.amazon.com/trustedadvisor/)
- [AWS Budgets](https://console.aws.amazon.com/billing/)

## Success Criteria

✅ **Complete Success**:
- Dev environment costs: <$5/month
- Only S3 state storage costs remain
- No orphaned resources found
- All expected resources terminated

⚠️ **Partial Success**:
- Costs reduced but not to baseline
- Some orphaned resources found
- Manual cleanup required

❌ **Failure**:
- Costs remain high
- Multiple resources still running
- Requires investigation