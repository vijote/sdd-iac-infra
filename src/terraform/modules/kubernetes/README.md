# Kubernetes Cluster Foundation Module

This Terraform module provisions a 3-node Kubernetes cluster (1 control plane, 2 workers) on AWS using kubeadm for bootstrap and Flannel for pod networking.

## Features

- Automated Kubernetes cluster provisioning
- Cloud-init scripts for node bootstrap
- Flannel CNI for pod networking
- Support for dev and prod environments
- Manual validation approach (no automated tests)
- Cost-optimized instance selection

## Architecture

```
┌─────────────────────────────────────────┐
│                VPC                      │
│  ┌─────────────┐  ┌─────────────┐       │
│  │ Control     │  │ Worker 1    │       │
│  │ Plane       │  │             │       │
│  │ t3.small    │  │ t3.micro    │       │
│  └─────────────┘  └─────────────┘       │
│  ┌─────────────┐                       │
│  │ Worker 2    │                       │
│  │ t3.micro    │                       │
│  └─────────────┘                       │
└─────────────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "kubernetes" {
  source = "./modules/kubernetes"
  
  cluster_name = "my-k8s-cluster"
  environment  = "dev"
  
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  security_group_ids = ["sg-xxxxx", "sg-yyyyy"]
  
  control_plane_instance_type = "t3.small"
  worker_instance_type        = "t3.micro"
  worker_count               = 2
}
```

### With Custom Variables

```hcl
module "kubernetes" {
  source = "./modules/kubernetes"
  
  cluster_name = "prod-k8s"
  environment  = "prod"
  aws_region   = "us-west-2"
  
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [
    module.security.control_plane_sg_id,
    module.security.worker_sg_id
  ]
  
  control_plane_instance_type = "t3.medium"
  worker_instance_type        = "t3.small"
  worker_count               = 3
  
  root_volume_size = 30
  pod_network_cidr = "10.244.0.0/16"
  ssh_key_name = "my-key-pair"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the Kubernetes cluster | `string` | n/a | yes |
| environment | Environment (dev, prod) | `string` | n/a | yes |
| aws_region | AWS region | `string` | `"us-east-1"` | no |
| subnet_ids | List of subnet IDs for instances | `list(string)` | n/a | yes |
| security_group_ids | List of security group IDs | `list(string)` | n/a | yes |
| control_plane_instance_type | EC2 instance type for control plane | `string` | `"t3.small"` | no |
| worker_instance_type | EC2 instance type for worker nodes | `string` | `"t3.micro"` | no |
| worker_count | Number of worker nodes | `number` | `2` | no |
| root_volume_size | Size of root volume in GB | `number` | `20` | no |
| pod_network_cidr | CIDR block for pod network | `string` | `"10.244.0.0/16"` | no |
| ssh_key_name | SSH key name for instances | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | Name of the Kubernetes cluster |
| control_plane_instance_id | ID of the control plane instance |
| control_plane_public_ip | Public IP of the control plane instance |
| control_plane_private_ip | Private IP of the control plane instance |
| worker_instance_ids | IDs of the worker instances |
| worker_public_ips | Public IPs of the worker instances |
| worker_private_ips | Private IPs of the worker instances |
| all_instance_ids | IDs of all instances (control plane + workers) |
| cluster_endpoint | Kubernetes API endpoint |

## Deployment Steps

### 1. Initialize Terraform

```bash
cd src/terraform/environments/dev
terraform init
```

### 2. Review Configuration

```bash
terraform plan
```

### 3. Deploy Cluster

```bash
terraform apply
```

### 4. Wait for Initialization

The cluster initialization takes 10-15 minutes. Monitor progress:

```bash
# Check instance status
aws ec2 describe-instances --filters "Name=tag:Cluster,Values=<cluster-name>"

# Check cloud-init logs
ssh -i <key> ubuntu@<control-plane-ip>
sudo tail -f /var/log/cloud-init-output.log
```

### 5. Configure kubectl

```bash
# SSH to control plane
ssh -i <key> ubuntu@<control-plane-ip>

# Copy kubeconfig
sudo cat /etc/kubernetes/admin.conf

# On local machine
mkdir -p ~/.kube
# Paste admin.conf content into ~/.kube/config
export KUBECONFIG=~/.kube/config
```

## Validation

### Check Node Status

```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME                       STATUS   ROLES           AGE   VERSION   INTERNAL-IP
ip-10-0-1-xxx.ec2.internal   Ready    control-plane   5m    v1.28.x   10.0.1.xxx
ip-10-0-2-xxx.ec2.internal   Ready    <none>          3m    v1.28.x   10.0.2.xxx
ip-10-0-2-yyy.ec2.internal   Ready    <none>          3m    v1.28.x   10.0.2.yyy
```

### Test Pod Networking

```bash
# Create test pods
kubectl run test-pod-1 --image=busybox --rm -it --restart=Never -- sleep 30 &
kubectl run test-pod-2 --image=busybox --rm -it --restart=Never -- sleep 30 &

# Test connectivity
kubectl exec test-pod-1 -- ping -c 3 <test-pod-2-ip>
```

### Check System Pods

```bash
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel
```

## Components

### Cloud-Init Scripts

- **Control Plane**: Installs containerd, kubeadm, initializes cluster, deploys Flannel
- **Worker Nodes**: Installs dependencies, joins cluster using generated token

### Networking

- **CNI**: Flannel with VXLAN backend
- **Pod CIDR**: 10.244.0.0/16 (configurable)
- **Service Network**: 10.96.0.0/12 (default)

### Security

- Security groups configured for Kubernetes communication
- IAM roles manually provisioned (per constitution)
- Flannel VXLAN encryption enabled

## Troubleshooting

### Common Issues

1. **Pods stuck in ContainerCreating**
   ```bash
   kubectl get pods -n kube-flannel
   kubectl logs -n kube-flannel -l app=flannel
   ```

2. **Workers not joining cluster**
   ```bash
   # Check join token validity
   ssh ubuntu@<worker-ip> sudo cat /var/log/cloud-init-output.log
   ```

3. **Network connectivity issues**
   ```bash
   # Check security group rules
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

### Recovery Commands

```bash
# Reset kubeadm on a node
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo systemctl restart kubelet

# Regenerate join command
sudo kubeadm token create --print-join-command
```

## Cost Optimization

- Development: t3.small + 2×t3.micro = ~$33/month
- Production: t3.medium + 3×t3.small = ~$54/month

## Dependencies

- Terraform 1.0+
- AWS Provider 5.0+
- VPC module (Spec 001)
- Security module (Spec 002)

## Limitations

- Single control plane (not HA)
- Manual scaling only
- No automated monitoring
- No backup/automation

## Future Enhancements

- Control plane HA (3 control plane nodes)
- Automated scaling
- Monitoring and logging
- Backup and disaster recovery
- GitOps integration

## Support

For detailed troubleshooting, see:
- [Network Troubleshooting Guide](../../../specs/003-kubernetes-cluster-foundation/network-troubleshooting.md)
- [Quick Start Guide](../../../specs/003-kubernetes-cluster-foundation/quickstart.md)