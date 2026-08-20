# Scaffolding Spec 003: EC2 Instances & kubeadm Bootstrap

**Version:** 1.0  
**Date:** 2026-08-20  
**Status:** Ready for Implementation  
**Phase:** Phase 1 (Foundation)  
**Depends On:** Scaffolding Specs 001 (Networking) & 002 (IAM)

---

## Overview

This spec defines **EC2 instance provisioning** and **Kubernetes bootstrap via kubeadm**. It brings together the networking layer (Spec 001) and IAM layer (Spec 002) to launch and initialize the Kubernetes cluster.

**Goal:** Create a working Kubernetes cluster with 1 control plane (t3.small) and 2 worker nodes (t3.micro), all bootstrapped automatically via cloud-init and kubeadm.

---

## Scope

### In Scope

1. **EC2 Instances**
   - 1 control plane instance (t3.small) in public subnet
   - 2 worker node instances (t3.micro) in private subnets
   - Ubuntu 22.04 LTS AMI (latest; cost-optimized)
   - Instance profiles linked to IAM roles from Spec 002
   - Public IP for control plane (for kubeadm bootstrap and kubectl access)
   - Private IPs for worker nodes (accessed via control plane)

2. **Cloud-Init Provisioning**
   - Install container runtime (containerd)
   - Install kubeadm, kubelet, kubectl
   - Configure cgroup drivers, kernel modules (VXLAN, overlay)
   - Initialize control plane with `kubeadm init`
   - Join worker nodes with `kubeadm join`
   - Deploy Flannel CNI plugin
   - Deploy CoreDNS

3. **Kubernetes Initialization**
   - Control plane API server (6443)
   - etcd for state management
   - kube-scheduler, kube-controller-manager
   - kube-proxy on all nodes
   - CoreDNS for service discovery
   - Flannel for pod networking (VXLAN)

4. **Output & Verification**
   - kubeconfig exported for kubectl access
   - Join token and CA certificate for worker nodes
   - Cluster health check (all nodes Ready)

### Out of Scope

- Multi-master HA (single control plane only)
- etcd backup/restore
- Advanced kubeadm configurations (custom audit logs, webhooks)
- Container image registries (use Docker Hub; private registries are future work)
- Pod Security Policies (out of scope per D007)

---

## Technical Design

### Kubernetes Architecture

```
┌────────────────────────────────────────────────────────┐
│              Control Plane (t3.small)                   │
│              Public Subnet 10.0.1.0/24                 │
├────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────────────────────────────┐          │
│  │ kube-apiserver (6443)                    │          │
│  ├──────────────────────────────────────────┤          │
│  │ kube-scheduler                           │          │
│  │ kube-controller-manager                  │          │
│  │ etcd (2379-2380)                         │          │
│  │ kubelet                                  │          │
│  │ kube-proxy                               │          │
│  │ CoreDNS                                  │          │
│  │ Flannel                                  │          │
│  └──────────────────────────────────────────┘          │
│         │                                               │
│         └─── Public IP (for kubectl access)            │
│         └─── Private IP 10.0.1.x (pod traffic)        │
│                                                         │
└────────────────────────────────────────────────────────┘
         │
         │ kubeadm join
         │ (Bootstrap token valid for 24h)
         │
  ┌──────┴────────┐
  │               │
  ▼               ▼
┌──────────────────────┐    ┌──────────────────────┐
│  Worker 1 (t3.micro) │    │  Worker 2 (t3.micro) │
│  Subnet 10.0.2.0/24  │    │  Subnet 10.0.3.0/24  │
├──────────────────────┤    ├──────────────────────┤
│ kubelet              │    │ kubelet              │
│ kube-proxy           │    │ kube-proxy           │
│ containerd           │    │ containerd           │
│ Flannel (VXLAN)      │    │ Flannel (VXLAN)      │
│ Private IP 10.0.2.x  │    │ Private IP 10.0.3.x  │
└──────────────────────┘    └──────────────────────┘
```

### Cloud-Init Bootstrap Flow

```
1. EC2 instance launches
   ↓
2. Cloud-init runs (as root)
   ↓
3. Update package manager
   ↓
4. Install container runtime (containerd)
   ↓
5. Install kubernetes tools (kubeadm, kubelet, kubectl)
   ↓
6. Configure kernel (cgroup driver, modules)
   ↓
7. ┌──────────────────────────┐
   │ For Control Plane:       │
   │ - kubeadm init           │
   │ - Extract join token     │
   │ - Deploy Flannel         │
   │ - Output kubeconfig      │
   └──────────────────────────┘
   ↓
8. ┌──────────────────────────┐
   │ For Worker Nodes:        │
   │ - Wait for CP bootstrap  │
   │ - kubeadm join           │
   │ - Verify kubelet running │
   └──────────────────────────┘
```

---

## Terraform Structure

### File Organization

```
src/terraform/
├── modules/
│   ├── networking/      # Spec 001
│   ├── iam/             # Spec 002
│   └── compute/
│       ├── main.tf              # EC2 instances, security group rules
│       ├── variables.tf          # Input variables
│       ├── outputs.tf            # Instance IPs, kubeconfig
│       └── cloud-init/           # Cloud-init scripts
│           ├── common.sh         # Common setup (containerd, kubeadm)
│           ├── control-plane.sh  # CP-specific init
│           └── worker.sh         # Worker-specific init
├── environments/
│   ├── aws/
│   │   ├── main.tf              # Calls all modules
│   │   └── terraform.tfvars
│   └── ministack/
│       ├── main.tf
│       └── terraform.tfvars
```

### Module Inputs (variables.tf)

```hcl
variable "vpc_id" {
  description = "VPC ID from networking module"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for control plane"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes"
  type        = list(string)
}

variable "cp_security_group_id" {
  description = "Control plane security group ID"
  type        = string
}

variable "worker_security_group_id" {
  description = "Worker security group ID"
  type        = string
}

variable "cp_instance_profile_name" {
  description = "Instance profile for control plane (from IAM module)"
  type        = string
}

variable "worker_instance_profile_name" {
  description = "Instance profile for worker nodes (from IAM module)"
  type        = string
}

variable "cp_instance_type" {
  description = "EC2 instance type for control plane"
  type        = string
  default     = "t3.small"  # 2 vCPU, 2 GB RAM
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.micro"  # 1 vCPU, 1 GB RAM
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.28"  # Latest stable
}

variable "pod_subnet_cidr" {
  description = "CIDR for pod networking (Flannel)"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_subnet_cidr" {
  description = "CIDR for services (cluster IP)"
  type        = string
  default     = "10.96.0.0/12"
}

variable "ami_filter" {
  description = "AMI name filter for Ubuntu 22.04 LTS"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "sdd-infra"
}

variable "environment" {
  description = "Environment (aws, ministack)"
  type        = string
  default     = "aws"
}
```

### Module Outputs (outputs.tf)

```hcl
output "control_plane_public_ip" {
  description = "Public IP of control plane (for kubectl access)"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of control plane (for pod networking)"
  value       = aws_instance.control_plane.private_ip
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file (will be exported during bootstrap)"
  value       = "/tmp/kubeconfig.yaml"
}

output "cluster_token" {
  description = "Kubernetes cluster token (for kubeadm join)"
  value       = "Retrieved from control plane after bootstrap"
}

output "bootstrap_complete" {
  description = "Whether bootstrap is complete (check node status)"
  value       = "Run: kubectl get nodes --kubeconfig=/tmp/kubeconfig.yaml"
}
```

---

## Cloud-Init Scripts

### common.sh

```bash
#!/bin/bash
set -e

# Configure kernel modules for container networking
modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl --system

# Install container runtime (containerd)
apt-get update
apt-get install -y containerd

# Configure containerd with systemd cgroup driver
mkdir -p /etc/containerd
containerd config default | sed 's/systemd_cgroup = false/systemd_cgroup = true/' > /etc/containerd/config.toml
systemctl restart containerd

# Install kubernetes tools
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key | apt-key add -
echo "deb https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
systemctl enable kubelet
```

### control-plane.sh

```bash
#!/bin/bash
set -e

# Initialize control plane with kubeadm
kubeadm init \
  --apiserver-advertise-address=${CP_PRIVATE_IP} \
  --pod-network-cidr=${POD_SUBNET_CIDR} \
  --service-cidr=${SERVICE_SUBNET_CIDR} \
  --skip-token-print

# Setup kubeconfig for root user
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Export kubeconfig for retrieval
cp /root/.kube/config /tmp/kubeconfig.yaml
chmod 644 /tmp/kubeconfig.yaml

# Deploy Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Generate join token (valid for 24 hours)
kubeadm token create --print-join-command > /tmp/join-command.sh
chmod +x /tmp/join-command.sh

# Wait for all system pods to be ready
kubectl wait --for=condition=Ready pod --all -n kube-system --timeout=5m
```

### worker.sh

```bash
#!/bin/bash
set -e

# Wait for control plane bootstrap (poll for join command)
# This is a simplified approach; in production, use a proper bootstrap token server
while [ ! -f /tmp/join-command.sh ]; do
  echo "Waiting for control plane bootstrap..."
  sleep 5
done

# Join the cluster
bash /tmp/join-command.sh
```

---

## Testing Strategy

### Unit Testing

```bash
cd src/terraform/environments/aws
terraform init
terraform plan -target=module.compute
# Verify all instances, security groups, and outputs are correct
```

### Integration Testing (Real AWS)

1. **Deploy infrastructure:**
   ```bash
   terraform apply -target=module.networking,module.iam,module.compute
   ```

2. **Wait for bootstrap (5-10 minutes):**
   ```bash
   # Monitor cloud-init logs
   aws ec2 get-console-output --instance-id i-xxxxxxxxxx
   ```

3. **Retrieve kubeconfig:**
   ```bash
   # Via Systems Manager Session Manager or SCP from control plane public IP
   scp -i ~/.ssh/sdd-infra-key.pem ubuntu@<CP_PUBLIC_IP>:/tmp/kubeconfig.yaml .
   ```

4. **Verify cluster health:**
   ```bash
   export KUBECONFIG=./kubeconfig.yaml
   kubectl get nodes  # Should show 1 control plane + 2 workers, all Ready
   kubectl get pods -n kube-system  # All pods should be Running
   ```

5. **Test pod networking:**
   ```bash
   kubectl run -it --rm debug --image=busybox -- sh
   # Inside pod:
   wget -q -O- http://10.96.0.10  # CoreDNS service (should respond)
   ```

### Ministack Testing

- Ministack likely doesn't support EC2; test Terraform validation only
- Focus on real AWS integration testing

---

## Success Criteria

✅ **EC2 Instances Created**
- [ ] Control plane instance launches in public subnet
- [ ] 2 worker instances launch in private subnets
- [ ] All instances pass status checks (2/2)
- [ ] Security groups attached correctly

✅ **Cloud-Init Bootstrap**
- [ ] Cloud-init completes without errors (check console output)
- [ ] containerd is installed and running
- [ ] kubeadm, kubelet, kubectl are installed

✅ **Kubernetes Cluster**
- [ ] `kubectl get nodes` shows 3 nodes, all in Ready state
- [ ] All kube-system pods are Running (kube-apiserver, etcd, Flannel, CoreDNS, etc.)
- [ ] Pod networking works (Flannel deployed, pods can ping each other)

✅ **kubeconfig & Access**
- [ ] kubeconfig exported and accessible
- [ ] kubectl commands work with the exported kubeconfig
- [ ] Control plane API is reachable from local machine (via public IP)

✅ **Cost Control**
- [ ] Estimated monthly cost for compute: ~$15-20 (1 t3.small + 2 t3.micro)
- [ ] No additional charges (no data transfer, no extra volumes)

---

## Dependencies & Assumptions

### External Dependencies
- AWS account with EC2, VPC, IAM permissions
- Terraform 1.0+
- AWS CLI configured
- kubectl installed locally (for verification)
- ssh access to control plane (via public IP or bastion)

### Assumptions
- Ubuntu 22.04 LTS AMI available in target region
- Control plane bootstrap completes within 10 minutes
- Worker join token is valid for 24 hours
- Pod subnet 10.244.0.0/16 does not conflict with VPC 10.0.0.0/16
- Internet connectivity available (for pulling container images, kubernetes packages)

---

## Known Limitations

1. **Single Control Plane:** Cluster is not HA; control plane failure = cluster loss. Acceptable for learning.
2. **Bootstrap Synchronization:** Worker nodes poll for join token; production would use a proper bootstrap server.
3. **kubeconfig in /tmp:** Not secure for production; this is for MVP. Consider storing in Secrets Manager.
4. **No kube-proxy iptables:** May hit kernel module limits on t3.micro. Monitor and document workarounds.

---

## Deliverables

1. **Terraform Module:** `src/terraform/modules/compute/` (complete, tested)
2. **Cloud-Init Scripts:** All bootstrap scripts in `src/terraform/modules/compute/cloud-init/`
3. **Environment Config:** Integration with `environments/aws/` main.tf
4. **Documentation:** This spec + inline comments in shell scripts
5. **Verification Report:** kubectl output showing healthy cluster

---

## Next Steps (Phase 2 & Beyond)

Once this spec is **complete & tested:**
1. ← **Scaffolding Spec 001 & 002:** Completed
2. → **Next Phase:** nginx-ingress, Route53, Secrets Manager integration
3. → **Validation:** End-to-end testing with sample apps

---

## Decision Log References

- **D002:** Terraform + kubeadm — This spec implements the kubeadm bootstrap approach
- **D001:** Pod Networking — Flannel deployed in cloud-init
- **D006:** EC2 Instance Sizing — t3.small for CP, t3.micro for workers

---

**Sign-Off:**
- **Author:** Coda
- **Status:** Ready for scaffolding implementation
