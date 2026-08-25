# Cleanup and Teardown Guide

## Overview

This guide provides procedures for safely decommissioning Kubernetes clusters and cleaning up AWS resources.

## Prerequisites

- Terraform CLI installed
- AWS CLI configured
- Appropriate IAM permissions
- Access to the Terraform state

## Environment Teardown

### Development Environment

```bash
# Navigate to dev environment
cd src/terraform/environments/dev

# Review what will be destroyed
terraform plan -destroy

# Destroy the infrastructure
terraform destroy

# Confirm when prompted
```

### Production Environment

```bash
# Navigate to prod environment
cd src/terraform/environments/prod

# Plan the destruction
terraform plan -destroy

# Execute destruction (requires extra confirmation for prod)
terraform destroy

# Type 'yes' when prompted
```

## Verification of Cleanup

### Check EC2 Instances

```bash
# Verify instances are terminated
aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=sdd-k8s-dev" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
  --output table

# Expected: No instances or 'terminated' state
```

### Check EBS Volumes

```bash
# Check for orphaned volumes
aws ec2 describe-volumes \
  --filters "Name=tag:Cluster,Values=sdd-k8s-dev" \
  --query "Volumes[*].[VolumeId,State,Size]" \
  --output table

# Clean up orphaned volumes if any
aws ec2 delete-volume --volume-id <volume-id>
```

### Check Security Groups

```bash
# List security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Cluster,Values=sdd-k8s-dev" \
  --query "SecurityGroups[*].[GroupId,GroupName]" \
  --output table

# Security groups should be automatically deleted with instances
```

## Manual Cleanup (If Terraform Fails)

### Force Terminate Instances

```bash
# Get instance IDs
aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=sdd-k8s-dev" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text

# Terminate instances
aws ec2 terminate-instances --instance-ids <instance-id-1> <instance-id-2> <instance-id-3>
```

### Delete EBS Volumes

```bash
# List all volumes with cluster tags
aws ec2 describe-volumes \
  --filters "Name=tag:Cluster,Values=sdd-k8s-dev" \
  --query "Volumes[*].VolumeId" \
  --output text

# Delete volumes
for vol in $(aws ec2 describe-volumes --filters "Name=tag:Cluster,Values=sdd-k8s-dev" --query "Volumes[*].VolumeId" --output text); do
  aws ec2 delete-volume --volume-id $vol
  echo "Deleted volume: $vol"
done
```

### Clean Up Terraform State

```bash
# Remove state file (if destroying the entire environment)
rm -f .terraform/terraform.tfstate

# Or remove specific resources from state
terraform state rm aws_instance.control_plane
terraform state rm aws_instance.workers
```

## Local Cleanup

### Remove kubeconfig

```bash
# Remove cluster kubeconfig
rm -f ~/.kube/config-sdd-k8s-dev
rm -f kubeconfig

# Unset KUBECONFIG if set
unset KUBECONFIG

# Remove from kubeconfig if merged
kubectl config delete-context sdd-k8s-dev
kubectl config delete-cluster sdd-k8s-dev
kubectl config delete-user sdd-k8s-dev-admin
```

### Clean SSH Keys

```bash
# Remove known hosts entries
ssh-keygen -R <control-plane-public-ip>
ssh-keygen -R <worker-1-public-ip>
ssh-keygen -R <worker-2-public-ip>

# Or remove all AWS entries
sed -i '/^1[0-9]\+\./d' ~/.ssh/known_hosts
```

### Remove Local Files

```bash
# Remove any downloaded scripts or configs
rm -f join-command.sh
rm -f admin.conf
rm -f *.pem
```

## Cost Monitoring After Cleanup

### Check Billing

```bash
# Get current month's cost (requires Cost Explorer API)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query "ResultsByTime[0].Groups[?contains(@.Keys[0], 'EC2')]" \
  --output table
```

### Set Up Billing Alerts

```bash
# Create billing alarm (if not already exists)
aws cloudwatch put-metric-alarm \
  --alarm-name "AWS Monthly Billing Alert" \
  --alarm-description "Alert when AWS costs exceed $10" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

## Emergency Procedures

### Immediate Resource Lockdown

If resources need to be stopped immediately:

```bash
# Stop all instances (not terminate)
aws ec2 stop-instances \
  --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Cluster,Values=sdd-k8s-dev" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

# Verify stopped
aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=sdd-k8s-dev" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
  --output table
```

### Network Isolation

```bash
# Remove all inbound rules from security groups
for sg in $(aws ec2 describe-security-groups \
  --filters "Name=tag:Cluster,Values=sdd-k8s-dev" \
  --query "SecurityGroups[*].GroupId" \
  --output text); do
  aws ec2 revoke-security-group-ingress --group-id $sg --ip-permissions "IpProtocol=-1,IpRanges=[{CidrIp='0.0.0.0/0'}]"
done
```

## Partial Cleanup Scenarios

### Remove Only Workers

```bash
# Terminate worker instances only
aws ec2 terminate-instances \
  --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Cluster,Values=sdd-k8s-dev" "Name=tag:Role,Values=worker" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

# Update Terraform state
terraform state rm aws_instance.workers
```

### Recreate Control Plane Only

```bash
# Remove control plane from state
terraform state rm aws_instance.control_plane

# Recreate with Terraform
terraform apply -target=aws_instance.control_plane
```

## Troubleshooting Cleanup Issues

### Terraform State Lock

```bash
# Force unlock if state is locked
terraform force-unlock LOCK_ID

# Or manually remove lock file
rm -f .terraform.tfstate.lock.info
```

### Resources Stuck in 'Terminating' State

```bash
# Force termination
aws ec2 terminate-instances --instance-ids <stuck-instance-id>

# Wait and check status
aws ec2 describe-instances --instance-ids <stuck-instance-id>

# If still stuck, contact AWS support
```

### Orphaned Resources

```bash
# Find all tagged resources
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Cluster,Values=sdd-k8s-dev \
  --query "ResourceTagMappingList[*].[ResourceARN,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# Manually clean up as needed
```

## Post-Cleanup Verification Checklist

- [ ] All EC2 instances terminated
- [ ] All EBS volumes deleted
- [ ] Security groups removed
- [ ] No elastic IPs allocated
- [ ] Terraform state cleaned
- [ ] Local configs removed
- [ ] SSH known hosts cleaned
- [ ] Billing shows no new charges
- [ ] Cost alerts configured

## Automation Script

Create a cleanup script for repeated use:

```bash
#!/bin/bash
# cleanup-cluster.sh

CLUSTER_NAME=${1:-sdd-k8s-dev}
ENVIRONMENT=${2:-dev}

echo "Cleaning up cluster: $CLUSTER_NAME in $ENVIRONMENT environment"

# Navigate to environment
cd "src/terraform/environments/$ENVIRONMENT"

# Destroy with auto-approval (use with caution)
terraform destroy -auto-approve

# Verify cleanup
echo "Verifying cleanup..."
aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=$CLUSTER_NAME" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
  --output table

echo "Cleanup complete!"
```

Usage:
```bash
chmod +x cleanup-cluster.sh
./cleanup-cluster.sh sdd-k8s-dev dev
```

## Safety Considerations

1. **Always use `terraform plan` before `destroy`**
2. **Double-check you're in the right environment**
3. **Backup important data before destruction**
4. **Use `-auto-approve` only in automation**
5. **Document any manual interventions**
6. **Monitor billing after cleanup**

## Recovery

If you accidentally destroy resources:

1. Check Terraform state for recent changes
2. Use `terraform apply` to recreate if state is intact
3. Restore from backups if available
4. Contact AWS support for emergency recovery (within 24 hours)