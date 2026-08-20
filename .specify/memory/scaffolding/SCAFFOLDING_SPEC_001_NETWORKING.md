# Scaffolding Spec 001: VPC & Networking Foundation

**Version:** 1.0  
**Date:** 2026-08-20  
**Status:** Ready for Implementation  
**Phase:** Phase 1 (Foundation)  

---

## Overview

This spec defines the first foundational layer: **AWS VPC, subnets, security groups, and route tables**. This is the network substrate upon which control plane, worker nodes, and applications depend.

**Goal:** Create a reusable, provider-agnostic Terraform module for VPC networking that works on both real AWS and ministack local environments.

---

## Scope

### In Scope

1. **VPC Creation**
   - CIDR block: configurable (default: 10.0.0.0/16 for AWS; 172.18.0.0/16 for ministack)
   - Enable DNS hostnames and DNS resolution
   - VPC tags for management and cost tracking

2. **Subnets**
   - 1 public subnet for control plane + ingress (10.0.1.0/24)
   - 2 private subnets for worker nodes (10.0.2.0/24, 10.0.3.0/24)
   - Configure route tables, internet gateway for public subnet
   - No NAT gateway initially (cost optimization; nodes reach AWS APIs via public IPs if needed)

3. **Security Groups**
   - **Control Plane SG:** Allow kubelet communication (6443), etcd (2379-2380), internal pod networking (VXLAN 4789)
   - **Worker Node SG:** Allow pod networking, inter-node communication, kubelet from control plane
   - **Ingress SG:** Allow HTTP/HTTPS from internet (80, 443)
   - All security groups allow inter-SG communication for pod-to-pod traffic

4. **Route Tables**
   - Public route table: internet gateway route (0.0.0.0/0)
   - Private route tables: local routing only (no internet gateway; nodes reach AWS via instance public IPs)
   - DNS routing via VPC DNS resolver

### Out of Scope

- NAT gateways (cost optimization)
- VPN/VPC peering (single environment only)
- Network ACLs (security groups sufficient for learning)
- VPC flow logs (observability deferred)
- Multi-AZ deployment (single AZ for MVP)

---

## Technical Design

### VPC Architecture

```
┌─────────────────────────────────────────────────┐
│         AWS Region (us-east-1)                   │
├─────────────────────────────────────────────────┤
│  VPC: 10.0.0.0/16                               │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │ Public Subnet 10.0.1.0/24            │       │
│  │ (Control Plane + Ingress)            │       │
│  │                                      │       │
│  │  IGW ──────── Route: 0.0.0.0/0       │       │
│  └──────────────────────────────────────┘       │
│           │ ENI (public IP)                      │
│           └─── Control Plane (t3.small)        │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │ Private Subnet 10.0.2.0/24           │       │
│  │ (Worker Nodes)                       │       │
│  │                                      │       │
│  │  Route: local                        │       │
│  └──────────────────────────────────────┘       │
│           │ ENI (private IP)                     │
│           └─── Worker 1 (t3.micro)             │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │ Private Subnet 10.0.3.0/24           │       │
│  │ (Worker Nodes)                       │       │
│  │                                      │       │
│  │  Route: local                        │       │
│  └──────────────────────────────────────┘       │
│           │ ENI (private IP)                     │
│           └─── Worker 2 (t3.micro)             │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │ Flannel VXLAN Tunnel (Pod Networking)│       │
│  │ (All subnets participate)            │       │
│  └──────────────────────────────────────┘       │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Security Group Rules

#### Control Plane SG (cp-sg)
| Direction | Protocol | Port(s)  | Source/Dest | Purpose |
|-----------|----------|----------|-------------|---------|
| Inbound   | TCP      | 6443     | 0.0.0.0/0  | Kubernetes API (for admin access; later restricted to bastion/VPN) |
| Inbound   | TCP      | 2379     | cp-sg, worker-sg | etcd peer communication |
| Inbound   | TCP      | 2380     | cp-sg, worker-sg | etcd client communication |
| Inbound   | UDP      | 4789     | worker-sg  | Flannel VXLAN (pod networking) |
| Ingress   | TCP      | 80       | igw        | (via ingress controller only) |
| Ingress   | TCP      | 443      | igw        | (via ingress controller only) |
| Outbound  | ALL      | ALL      | 0.0.0.0/0  | All outbound (AWS APIs, DNS, etc.) |

#### Worker Node SG (worker-sg)
| Direction | Protocol | Port(s)  | Source/Dest | Purpose |
|-----------|----------|----------|-------------|---------|
| Inbound   | TCP      | 10250    | cp-sg, worker-sg | kubelet API |
| Inbound   | UDP      | 4789     | cp-sg, worker-sg | Flannel VXLAN |
| Inbound   | TCP      | 30000-32767 | 0.0.0.0/0  | NodePort services (if needed) |
| Outbound  | ALL      | ALL      | 0.0.0.0/0  | All outbound |

#### Ingress SG (ingress-sg)
| Direction | Protocol | Port(s)  | Source/Dest | Purpose |
|-----------|----------|----------|-------------|---------|
| Inbound   | TCP      | 80       | 0.0.0.0/0  | HTTP from internet |
| Inbound   | TCP      | 443      | 0.0.0.0/0  | HTTPS from internet |
| Outbound  | ALL      | ALL      | 0.0.0.0/0  | All outbound |

---

## Terraform Structure

### File Organization

```
src/terraform/
├── modules/
│   └── networking/
│       ├── main.tf              # VPC, subnets, IGW
│       ├── security_groups.tf   # Security group rules
│       ├── route_tables.tf       # Routing configuration
│       ├── variables.tf          # Input variables
│       └── outputs.tf            # Exported values (VPC ID, subnet IDs, etc.)
├── environments/
│   ├── aws/
│   │   ├── main.tf              # AWS provider + call networking module
│   │   ├── terraform.tfvars     # AWS-specific values
│   │   └── backend.tf           # S3 + DynamoDB remote state
│   └── ministack/
│       ├── main.tf              # Ministack provider + call networking module
│       ├── terraform.tfvars     # Ministack-specific values
│       └── backend.tf           # Local state (or no backend)
└── shared/
    └── versions.tf              # Terraform version, required providers
```

### Module Inputs (variables.tf)

```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"  # AWS default
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet (control plane)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (worker nodes)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zone" {
  description = "AZ for all subnets (MVP: single AZ)"
  type        = string
  default     = "us-east-1a"
}

variable "environment" {
  description = "Environment name (aws, ministack)"
  type        = string
  default     = "aws"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "sdd-infra"
}

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT gateway (cost: ~$0.045/hour)"
  type        = bool
  default     = false  # Cost optimization
}
```

### Module Outputs (outputs.tf)

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID (control plane)"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (worker nodes)"
  value       = aws_subnet.private[*].id
}

output "cp_security_group_id" {
  description = "Control plane security group ID"
  value       = aws_security_group.control_plane.id
}

output "worker_security_group_id" {
  description = "Worker node security group ID"
  value       = aws_security_group.worker.id
}

output "ingress_security_group_id" {
  description = "Ingress controller security group ID"
  value       = aws_security_group.ingress.id
}
```

---

## Testing Strategy

### Unit Testing (Local Terraform Validation)

```bash
# For both aws/ and ministack/ environments:
terraform init
terraform validate
terraform plan -out=tfplan
# Review tfplan before applying
```

### Integration Testing (Ministack)

1. **Deploy to ministack:**
   ```bash
   cd src/terraform/environments/ministack
   terraform apply -auto-approve
   ```

2. **Verify VPC & subnets exist:**
   ```bash
   # Ministack-specific commands (TBD based on ministack provider)
   ```

3. **Verify security group rules are correct:**
   - No overly permissive rules (except to 0.0.0.0/0 for ingress)
   - All inter-SG rules are defined

4. **DNS resolution test:**
   - Launch a test instance; verify it can resolve internal DNS

### Production Testing (Real AWS)

After ministack validation:

1. **Deploy to AWS sandbox/dev account:**
   ```bash
   cd src/terraform/environments/aws
   terraform apply
   ```

2. **Verify resources exist:**
   ```bash
   aws ec2 describe-vpcs --filters "Name=tag:Project,Values=sdd-infra"
   aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
   aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>"
   ```

3. **Cost validation:**
   ```bash
   # VPC + subnets + security groups: ~$0.00/month (no extra charges)
   # IGW: ~$0.00/month (free tier)
   # Total: <$1/month
   ```

---

## Success Criteria

✅ **Terraform Code Quality**
- [ ] `terraform validate` passes
- [ ] `terraform fmt` passes (code is formatted)
- [ ] All variables have descriptions
- [ ] All outputs are documented

✅ **AWS Resources Created**
- [ ] VPC exists with correct CIDR block
- [ ] 1 public subnet, 2 private subnets created
- [ ] Internet Gateway attached to public subnet
- [ ] Route tables configured correctly
- [ ] All resources tagged with project/environment

✅ **Security Groups Correct**
- [ ] Control plane SG allows kubeadm ports
- [ ] Worker SG allows kubelet + VXLAN
- [ ] Ingress SG allows HTTP/HTTPS
- [ ] No unexpected wide-open rules (0.0.0.0/0 only where necessary)

✅ **Ministack Validation**
- [ ] Module deploys to ministack without errors
- [ ] Ministack VPC resources created (if ministack supports VPC)
- [ ] Security group rules applied (if ministack supports them)

✅ **Cost Control**
- [ ] Estimated monthly cost for networking: <$1 (free tier)
- [ ] No NAT gateways, no data transfer charges

---

## Dependencies & Assumptions

### External Dependencies
- AWS account (or ministack equivalent) with VPC permissions
- Terraform 1.0+ installed locally
- AWS CLI configured with credentials

### Assumptions
- Single AZ deployment (us-east-1a)
- VPC CIDR 10.0.0.0/16 does not conflict with existing VPCs
- Internet connectivity available from all instances (public IPs)

---

## Deliverables

1. **Terraform Module:** `src/terraform/modules/networking/` (complete, tested)
2. **Environment Configs:** `src/terraform/environments/aws/` and `src/terraform/environments/ministack/` (both ready to deploy)
3. **Documentation:** This spec + inline code comments explaining the architecture
4. **Test Results:** Validation output from `terraform plan` + ministack deployment logs
5. **Cost Report:** Estimated monthly AWS cost for this layer

---

## Next Steps

Once this spec is **complete & tested**:
1. → **Scaffolding Spec 002:** IAM Roles & Policies (EC2 instance profiles, service account roles)
2. → **Scaffolding Spec 003:** EC2 Instances & kubeadm Bootstrap

---

## Decision Log References

- **D001:** Pod Networking — Choose Flannel (VXLAN requires UDP 4789)
- **D006:** EC2 Instance Sizing — t3.small (CP) + t3.micro (workers) — network must support these sizes
- **D002:** Terraform + kubeadm — Networking layer is the foundation for kubeadm bootstrap

---

**Sign-Off:**
- **Author:** Coda
- **Status:** Ready for scaffolding implementation
