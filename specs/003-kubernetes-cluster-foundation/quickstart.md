# Quickstart Guide: Kubernetes Cluster Foundation

**Created**: 2025-08-24  
**Purpose**: End-to-end validation scenarios for the Kubernetes cluster

## Prerequisites

### Tools Required
- Terraform 1.0+ installed
- AWS CLI configured with appropriate permissions
- kubectl 1.28+ (for post-deployment validation)
- SSH key pair created in AWS

### AWS Permissions
- EC2 instance management
- VPC and subnet access
- Security group management
- EBS volume management
- IAM instance profile usage

### Dependencies
- Spec 001: VPC Networking Foundation must be deployed
- Spec 002: Secure Deployment Foundation must be deployed

## Deployment Steps

### 1. Prepare Environment

```bash
# Clone repository
git clone <repository-url>
cd sdd-infra

# Initialize Terraform
cd src/terraform/environments/dev
terraform init

# Verify configuration
terraform fmt
terraform validate
```

### 2. Configure Variables

Create `terraform.tfvars`:
```hcl
cluster_name = "sdd-k8s-dev"
key_pair_name = "your-ssh-key-name"

# From Spec 001
vpc_id = "vpc-xxxxxxxxx"
subnet_ids = ["subnet-xxxxxxxx", subnet-yyyyyyyy"]

# From Spec 002
control_plane_security_group_id = "sg-xxxxxxxx"
worker_security_group_id = "sg-yyyyyyyy"
```

### 3. Deploy Infrastructure

```bash
# Review the plan
terraform plan

# Apply the configuration
terraform apply -auto-approve
```

Expected output:
- 3 EC2 instances created
- Control plane public IP displayed
- kubeconfig content shown (sensitive)
- Join command displayed (sensitive)

### 4. Save Outputs

```bash
# Save control plane IP
CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip)
echo "Control Plane IP: $CONTROL_PLANE_IP"

# Save kubeconfig
terraform output kubeconfig > kubeconfig
export KUBECONFIG=$PWD/kubeconfig
```

## Validation Scenarios

### Scenario 1: Verify Instance Status

**Objective**: Confirm all EC2 instances are running

**Steps**:
```bash
# Check instance status via AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=sdd-k8s-dev-*" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]" \
  --output table
```

**Expected Output**:
```
-------------------------------------------------
|         DescribeInstances                    |
+----------------------+-------------+--------+
|  i-xxxxxxxxxxxxxx    |  running    |  t3.small  |
|  i-yyyyyyyyyyyyyy    |  running    |  t3.micro  |
|  i-zzzzzzzzzzzzzz    |  running    |  t3.micro  |
+----------------------+-------------+--------+
```

### Scenario 2: Access Control Plane

**Objective**: Verify SSH access to control plane

**Steps**:
```bash
# SSH to control plane
ssh -i your-key.pem ubuntu@$CONTROL_PLANE_IP

# Check cloud-init status
sudo cloud-init status
# Expected: status: done

# Check initialization logs
sudo tail -f /var/log/cloud-init-output.log
```

**Expected Results**:
- SSH connection successful
- cloud-init status shows "done"
- No errors in initialization logs

### Scenario 3: Verify Cluster Status

**Objective**: Confirm Kubernetes cluster is operational

**Steps**:
```bash
# On control plane, check node status
sudo kubectl get nodes -o wide
```

**Expected Output**:
```
NAME               STATUS   ROLES           AGE   VERSION   INTERNAL-IP      EXTERNAL-IP
ip-10-0-1-100      Ready    control-plane   5m    v1.28.0   10.0.1.100       <control-plane-ip>
ip-10-0-1-101      Ready    <none>          3m    v1.28.0   10.0.1.101       <none>
ip-10-0-1-102      Ready    <none>          3m    v1.28.0   10.0.1.102       <none>
```

### Scenario 4: Validate Networking

**Objective**: Confirm pod-to-pod communication

**Steps**:
```bash
# Deploy test pods
sudo kubectl run test-pod-1 --image=busybox --restart=Never -- sleep 3600
sudo kubectl run test-pod-2 --image=busybox --restart=Never -- sleep 3600

# Wait for pods to be ready
sudo kubectl wait --for=condition=Ready pod/test-pod-1 --timeout=60s
sudo kubectl wait --for=condition=Ready pod/test-pod-2 --timeout=60s

# Test pod-to-pod communication
sudo kubectl exec test-pod-1 -- ping -c 3 10.244.2.2
```

**Expected Results**:
- Both pods become Ready
- Ping successful with <1ms latency

### Scenario 5: Verify Service Discovery

**Objective**: Confirm CoreDNS is working

**Steps**:
```bash
# Test DNS resolution
sudo kubectl exec test-pod-1 -- nslookup kubernetes.default

# Test service connectivity
sudo kubectl run dns-test --image=busybox --restart=Never --rm -it -- nslookup kubernetes.default.svc.cluster.local
```

**Expected Results**:
- DNS resolves successfully
- Service name resolves to cluster IP

### Scenario 6: Validate CNI

**Objective**: Confirm Flannel CNI is operational

**Steps**:
```bash
# Check Flannel pods
sudo kubectl get pods -n kube-flannel

# Check network interfaces
sudo kubectl exec test-pod-1 -- ip addr show flannel.1
```

**Expected Results**:
- All Flannel pods are Running
- Flannel interface exists with VXLAN endpoint

## Troubleshooting Guide

### Common Issues

1. **Instance Not Booting**
   - Check AWS Console for instance status
   - Verify security group allows SSH
   - Check subnet has available IP addresses

2. **Cloud-init Fails**
   - SSH to instance and check logs: `sudo tail -f /var/log/cloud-init-output.log`
   - Verify user-data script is valid YAML
   - Check internet connectivity for package downloads

3. **kubeadm Init Fails**
   - Check system resources (CPU, RAM)
   - Verify container runtime is running
   - Check port conflicts (6443, 2379-2380)

4. **Workers Not Joining**
   - Verify join token is valid (24-hour expiry)
   - Check network connectivity to control plane
   - Verify certificate hash matches

5. **Pod Networking Issues**
   - Check Flannel pods are running
   - Verify VXLAN port 4789 is open
   - Check node-to-node connectivity

### Recovery Commands

```bash
# Reset kubeadm (if needed)
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo systemctl restart kubelet

# Reinitialize control plane
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Regenerate join command
sudo kubeadm token create --print-join-command
```

## Cleanup

### Remove Cluster

```bash
# Destroy infrastructure
cd src/terraform/environments/dev
terraform destroy -auto-approve

# Remove local files
rm -f kubeconfig
unset KUBECONFIG
```

### Verify Cleanup

```bash
# Check instances are terminated
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=sdd-k8s-dev-*" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
  --output table
```

## Success Criteria

The deployment is successful when:
- [ ] All 3 EC2 instances are running
- [ ] Control plane accessible via SSH
- [ ] Kubernetes cluster initialized (1 control plane, 2 workers)
- [ ] All nodes in Ready state
- [ ] Pod-to-pod communication working
- [ ] Service discovery functional
- [ ] Flannel CNI operational
- [ ] Monthly cost under $50

## Next Steps

After successful validation:
1. Deploy applications to the cluster
2. Configure monitoring and logging
3. Set up backup procedures
4. Plan for production deployment