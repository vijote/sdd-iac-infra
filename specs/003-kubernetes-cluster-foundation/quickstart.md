# Kubernetes Cluster Foundation - Quick Start Guide

## Overview

This guide provides step-by-step instructions for deploying and validating a 3-node Kubernetes cluster (1 control plane, 2 workers) on AWS using Terraform.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform 1.0+ installed
- kubectl installed
- SSH access to AWS instances (optional)

## Deployment Steps

### 1. Deploy Infrastructure

```bash
# Navigate to the dev environment
cd src/terraform/environments/dev

# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 2. Wait for Cluster Initialization

The cluster initialization takes approximately 10-15 minutes. You can monitor progress:

```bash
# Check instance status in AWS console or via CLI
aws ec2 describe-instances --filters "Name=tag:Cluster,Values=sdd-k8s-dev"

# SSH to control plane to check logs (optional)
ssh -i <your-key> ubuntu@<control-plane-public-ip>
sudo tail -f /var/log/cloud-init-output.log
```

### 3. Configure kubectl

After the control plane is ready:

```bash
# SSH to control plane
ssh -i <your-key> ubuntu@<control-plane-public-ip>

# Copy kubeconfig
sudo cat /etc/kubernetes/admin.conf

# On your local machine, create kubeconfig
mkdir -p ~/.kube
# Paste the admin.conf content into ~/.kube/config
# Or use:
scp -i <your-key> ubuntu@<control-plane-public-ip>:/etc/kubernetes/admin.conf ~/.kube/config
export KUBECONFIG=~/.kube/config
```

## Manual Validation Guide

### 1. Verify Instance Status

**Check in AWS Console:**
1. Navigate to EC2 Instances
2. Verify all 3 instances are running
3. Check instance tags: `sdd-k8s-dev-control-plane`, `sdd-k8s-dev-worker-1`, `sdd-k8s-dev-worker-2`

**Or via CLI:**
```bash
aws ec2 describe-instances --filters "Name=tag:Cluster,Values=sdd-k8s-dev" --query "Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,Name:Tags[?Key=='Name'].Value|[0]}" --output table
```

### 2. Access Control Plane

```bash
# SSH to control plane
ssh -i <your-key> ubuntu@<control-plane-public-ip>

# Check if kubeadm initialization completed
sudo kubectl get nodes
```

Expected output:
```
NAME                       STATUS   ROLES           AGE   VERSION
ip-10-0-1-xxx.ec2.internal   Ready    control-plane   5m    v1.28.x
ip-10-0-2-xxx.ec2.internal   Ready    <none>          3m    v1.28.x
ip-10-0-2-yyy.ec2.internal   Ready    <none>          3m    v1.28.x
```

### 3. Check Cluster Status

```bash
# Verify all nodes are Ready
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Verify all system pods are Running
kubectl get pods -n kube-system | grep -v Running
```

### 4. Validate Networking

#### Test Pod-to-Pod Communication

```bash
# Create test pods
kubectl run test-pod-1 --image=busybox --rm -it --restart=Never -- sleep 300 &
kubectl run test-pod-2 --image=busybox --rm -it --restart=Never -- sleep 300 &

# Wait for pods to be ready
kubectl wait --for=condition=ready pod/test-pod-1 --timeout=60s
kubectl wait --for=condition=ready pod/test-pod-2 --timeout=60s

# Get pod IPs
POD1_IP=$(kubectl get pod test-pod-1 -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod test-pod-2 -o jsonpath='{.status.podIP}')

# Test connectivity
kubectl exec test-pod-1 -- ping -c 3 $POD2_IP
kubectl exec test-pod-2 -- ping -c 3 $POD1_IP

# Clean up
kubectl delete pod test-pod-1 test-pod-2
```

#### Test Service Discovery

```bash
# Create a test service
kubectl create deployment test-nginx --image=nginx --port=80
kubectl expose deployment test-nginx --port=80 --target-port=80

# Test service access
kubectl run test-client --image=busybox --rm -it --restart=Never -- wget -qO- http://test-nginx.default.svc.cluster.local

# Clean up
kubectl delete deployment test-nginx
kubectl delete service test-nginx
```

### 5. Verify Flannel CNI

```bash
# Check Flannel pods
kubectl get pods -n kube-flannel

# Check Flannel network interface
kubectl exec -n kube-flannel -l app=flannel -- ip addr show flannel.1

# Verify pod network
kubectl get pods -o wide
```

## Troubleshooting Common Issues

### Instance Not Starting

1. Check AWS CloudTrail for any API errors
2. Verify IAM roles have sufficient permissions
3. Check if instance type is available in the region

### Cluster Initialization Fails

1. Check cloud-init logs: `sudo tail -f /var/log/cloud-init-output.log`
2. Verify all required packages installed
3. Check if ports 6443, 2379-2380 are open in security groups

### Network Issues

1. Verify security group rules allow pod network traffic
2. Check if VPC routing is configured correctly
3. See [network-troubleshooting.md](network-troubleshooting.md) for detailed steps

### Pods Stuck in ContainerCreating

1. Check CNI installation: `kubectl get pods -n kube-flannel`
2. Verify pod network CIDR doesn't overlap with VPC CIDR
3. Restart Flannel: `kubectl delete pods -n kube-flannel -l app=flannel`

## Cleanup

To destroy the cluster:

```bash
cd src/terraform/environments/dev
terraform destroy
```

## Production Considerations

For production deployment:

1. Use larger instance types (t3.medium or higher)
2. Enable control plane HA (multiple control plane nodes)
3. Configure proper backup and disaster recovery
4. Set up monitoring and logging
5. Use private subnets with NAT gateways
6. Enable encryption at rest for EBS volumes

## Network Troubleshooting

### Common Network Issues

#### Flannel CNI Issues
- **Symptoms**: Pods stuck in `ContainerCreating`, `cni0` interface not found
- **Solution**: 
  ```bash
  kubectl get pods -n kube-flannel
  kubectl logs -n kube-flannel -l app=flannel
  kubectl delete pods -n kube-flannel -l app=flannel
  ```

#### CoreDNS Issues
- **Symptoms**: Service names don't resolve, `nslookup` failures
- **Solution**:
  ```bash
  kubectl get pods -n kube-system -l k8s-app=kube-dns
  kubectl logs -n kube-system -l k8s-app=kube-dns
  kubectl delete pods -n kube-system -l k8s-app=kube-dns
  ```

#### Pod Network Connectivity
- **Symptoms**: Pods cannot communicate across nodes
- **Solution**:
  ```bash
  # Check security group rules
  aws ec2 describe-security-groups --group-ids <sg-id>
  # Verify VXLAN traffic (UDP port 4789) is allowed
  ```

### Network Validation Commands
```bash
# Test pod-to-pod communication
kubectl exec <pod1> -- ping <pod2-ip>

# Test service discovery
kubectl exec <pod> -- nslookup kubernetes.default

# Check network policies
kubectl get networkpolicies --all-namespaces
```

## Support

For issues not covered in this guide:
1. Review cloud-init logs on each instance
2. Check Terraform state for any failed resources
3. Verify AWS service limits and quotas