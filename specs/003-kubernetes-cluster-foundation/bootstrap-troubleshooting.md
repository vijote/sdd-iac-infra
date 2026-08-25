# Bootstrap Troubleshooting Guide

## Common Bootstrap Issues

### Control Plane Initialization Failures

#### kubeadm init fails
**Symptoms**: Control plane instance boots but Kubernetes doesn't initialize

**Troubleshooting Steps**:
```bash
# Check cloud-init logs
ssh -i <key> ubuntu@<control-plane-ip>
sudo tail -f /var/log/cloud-init-output.log

# Check if kubeadm was installed
which kubeadm
kubeadm version

# Check system requirements
free -h
df -h
cat /proc/swaps
```

**Common Solutions**:
1. **Insufficient memory**: Ensure instance has at least 2GB RAM
2. **Swap enabled**: Kubernetes requires swap to be disabled
   ```bash
   sudo swapoff -a
   sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
   ```
3. **Container runtime issues**:
   ```bash
   sudo systemctl status containerd
   sudo journalctl -u containerd
   ```

#### etcd fails to start
**Symptoms**: etcd pod in CrashLoopBackOff

**Solution**:
```bash
# Check etcd logs
sudo journalctl -u etcd

# Reset and reinitialize
sudo kubeadm reset
sudo rm -rf /var/lib/etcd
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

### Worker Node Join Failures

#### Worker cannot join cluster
**Symptoms**: Worker boots but doesn't appear in `kubectl get nodes`

**Troubleshooting**:
```bash
# SSH to worker node
ssh -i <key> ubuntu@<worker-ip>

# Check cloud-init logs
sudo tail -f /var/log/cloud-init-output.log

# Check if join command executed
ls -la /tmp/kubeadm-join.sh
sudo cat /tmp/kubeadm-join.sh

# Manual join attempt
sudo bash /tmp/kubeadm-join.sh
```

**Common Issues**:
1. **Token expired**: Tokens expire after 24 hours
   ```bash
   # On control plane, generate new token
   sudo kubeadm token create --print-join-command
   ```

2. **Network connectivity**: Worker can't reach control plane
   ```bash
   # Test connectivity
   ping <control-plane-private-ip>
   telnet <control-plane-private-ip> 6443
   ```

3. **Firewall/Security Group**: Port 6443 blocked
   - Check AWS security groups allow traffic on port 6443
   - Ensure control plane and workers are in the same security group or have proper rules

### Container Runtime Issues

#### containerd fails to start
**Symptoms**: Pods stuck in ContainerCreating

**Solution**:
```bash
# Check containerd status
sudo systemctl status containerd

# Restart containerd
sudo systemctl restart containerd

# Check configuration
sudo containerd config dump

# Reset containerd
sudo systemctl stop containerd
sudo rm -rf /var/lib/containerd/*
sudo systemctl start containerd
```

#### CNI plugin issues
**Symptoms**: Network interface not created in pods

**Solution**:
```bash
# Check CNI plugins
ls -la /opt/cni/bin/

# Reinstall CNI
sudo apt-get install --reinstall kubernetes-cni

# Check network configuration
ip addr show
route -n
```

### Package Installation Issues

#### apt-get fails during cloud-init
**Symptoms**: Package installation errors in cloud-init logs

**Solution**:
```bash
# Update package lists
sudo apt-get update

# Fix broken packages
sudo apt-get -f install

# Retry installation
sudo apt-get install -y containerd.io kubelet kubeadm kubectl
```

#### GPG key errors
**Symptoms**: GPG verification failures

**Solution**:
```bash
# Re-add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Re-add Kubernetes GPG key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

# Update and retry
sudo apt-get update
```

### Instance Access Issues

#### SSH access fails
**Symptoms**: Cannot SSH to instances

**Checks**:
1. **Security Group**: Port 22 open in security group
2. **SSH Key**: Correct key pair associated with instance
3. **Network**: Instance in public subnet with internet gateway
4. **Instance Status**: Instance running and passed health checks

#### Instance fails to boot
**Symptoms**: Instance status shows initialization failed

**Solution**:
```bash
# Check instance console output in AWS console
# Look for errors in:
# - User data execution
# - Cloud-init logs
# - System boot logs
```

## Recovery Procedures

### Full Cluster Reset
```bash
# On all nodes:
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo systemctl restart kubelet

# On control plane:
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# On workers:
# Get new join command from control plane
sudo kubeadm token create --print-join-command
# Execute on workers
```

### Selective Node Recovery
```bash
# Drain problematic node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Reset the node
ssh ubuntu@<node-ip> "sudo kubeadm reset"

# Rejoin the node
# Generate new join token on control plane
# Execute join on worker
```

## Debug Commands

### Control Plane Diagnostics
```bash
# Check cluster status
kubectl get componentstatuses
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check API server logs
sudo journalctl -u kube-apiserver
```

### Worker Node Diagnostics
```bash
# Check kubelet status
sudo systemctl status kubelet
sudo journalctl -u kubelet

# Check kube-proxy
sudo systemctl status kube-proxy
sudo journalctl -u kube-proxy

# Check network interfaces
ip addr show
ip route show
```

## Prevention Tips

1. **Use appropriate instance sizes**: Minimum t3.small for control plane
2. **Disable swap**: Ensure swap is disabled before initialization
3. **Check security groups**: Allow all required Kubernetes ports
4. **Monitor resources**: Ensure sufficient CPU and memory
5. **Use reliable AMIs**: Stick with official Ubuntu 22.04 LTS

## Getting Help

1. Check AWS CloudTrail for API errors
2. Review cloud-init logs on each instance
3. Verify Terraform state for failed resources
4. Check AWS service limits and quotas
5. Consult Kubernetes documentation for specific errors