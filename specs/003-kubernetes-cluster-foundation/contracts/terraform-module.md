# Terraform Module Contract: Kubernetes Cluster Foundation

**Created**: 2025-08-24  
**Purpose**: Define the interface contract for the Kubernetes Terraform module

## Module Interface

### Module Path
```
src/terraform/modules/kubernetes/
```

### Input Variables

#### Required Variables

```hcl
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for instance placement"
  type        = list(string)
}

variable "control_plane_security_group_id" {
  description = "Security group ID for control plane node"
  type        = string
}

variable "worker_security_group_id" {
  description = "Security group ID for worker nodes"
  type        = string
}

variable "key_pair_name" {
  description = "SSH key pair name for instance access"
  type        = string
}
```

#### Optional Variables

```hcl
variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.28.0"
}

variable "instance_types" {
  description = "Instance types for control plane and workers"
  type = object({
    control_plane = string
    workers       = string
  })
  default = {
    control_plane = "t3.small"
    workers       = "t3.micro"
  }
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### Output Values

```hcl
output "cluster_name" {
  description = "Name of the created Kubernetes cluster"
  value       = var.cluster_name
}

output "control_plane_instance_id" {
  description = "EC2 instance ID of the control plane node"
  value       = aws_instance.control_plane.id
}

output "control_plane_public_ip" {
  description = "Public IP address of the control plane node"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP address of the control plane node"
  value       = aws_instance.control_plane.private_ip
}

output "worker_instance_ids" {
  description = "List of EC2 instance IDs for worker nodes"
  value       = aws_instance.workers[*].id
}

output "worker_private_ips" {
  description = "List of private IP addresses for worker nodes"
  value       = aws_instance.workers[*].private_ip
}

output "kubeconfig" {
  description = "Kubernetes configuration file content"
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}

output "join_command" {
  description = "Command for workers to join the cluster"
  value       = local.join_command
  sensitive   = true
}
```

## Module Dependencies

### Required Modules
- `vpc` (from Spec 001): Provides VPC, subnets, and base networking
- `secure-deployment` (from Spec 002): Provides security context and IAM references

### External Dependencies
- AWS Provider (>= 4.0)
- Terraform (>= 1.0)
- kubectl (for manual validation, not used in module)

## Resource Requirements

### AWS Resources
- `aws_instance`: 3 EC2 instances (1 control plane, 2 workers)
- `aws_ebs_volume`: 3 EBS volumes (20GB each)
- `aws_security_group_rule`: Rules for Kubernetes communication
- `aws_iam_instance_profile`: Instance profile for EC2 instances

### Data Sources
- `aws_ami`: Ubuntu 22.04 LTS AMI
- `aws_vpc`: VPC information
- `aws_subnet`: Subnet information

## Implementation Constraints

### Security Requirements
- All instances must use IAM instance profiles
- Control plane must have restricted access
- Workers must not have public IP addresses
- All inter-node communication must be encrypted

### Performance Requirements
- Cluster initialization must complete within 15 minutes
- Pod-to-pod communication latency < 50ms
- All nodes must be Ready within 10 minutes of boot

### Cost Constraints
- Total monthly cost must not exceed $50
- Instance types limited to t3.small and t3.micro
- EBS volumes limited to 20GB each

## Integration Points

### With VPC Module (Spec 001)
```hcl
module "kubernetes" {
  source = "../../modules/kubernetes"
  
  vpc_id                        = module.vpc.vpc_id
  subnet_ids                    = module.vpc.private_subnet_ids
  control_plane_security_group_id = module.vpc.control_plane_sg_id
  worker_security_group_id      = module.vpc.worker_sg_id
  
  # ... other variables
}
```

### With Secure Deployment Module (Spec 002)
```hcl
module "kubernetes" {
  source = "../../modules/kubernetes"
  
  # Security groups from secure deployment
  control_plane_security_group_id = module.secure_deployment.kubernetes_control_plane_sg_id
  worker_security_group_id      = module.secure_deployment.kubernetes_worker_sg_id
  
  # IAM instance profile
  key_pair_name                = module.secure_deployment.key_pair_name
  
  # ... other variables
}
```

## Validation Requirements

### Pre-Apply Validation
- VPC must exist and be available
- Subnets must be in same VPC
- Security groups must allow required ports
- Key pair must exist

### Post-Apply Validation
- All EC2 instances must be running
- Cloud-init logs must show successful execution
- Control plane must be accessible
- Workers must be able to join cluster

## Error Handling

### Expected Error Scenarios
1. **Instance Launch Failure**: Retry with different AZ
2. **Cloud-init Failure**: Log to /var/log/cloud-init-output.log
3. **kubeadm Init Failure**: Check resource availability
4. **Network Connectivity**: Verify security group rules

### Error Reporting
- All errors logged to Terraform state
- Cloud-init logs preserved in instance
- Manual troubleshooting steps documented

## Version Compatibility

### Terraform Version
- Minimum: 1.0.0
- Recommended: 1.5.0 or later

### Provider Versions
- AWS Provider: >= 4.0
- Kubernetes Provider: Not used (manual validation only)

### Kubernetes Version
- Supported: 1.28.x
- Tested: 1.28.0