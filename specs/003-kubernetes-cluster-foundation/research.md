# Research: Kubernetes Cluster Foundation

**Created**: 2025-08-24  
**Purpose**: Research findings for implementation decisions

## Research Tasks & Findings

### 1. EC2 Instance Types and Sizing

**Research Question**: What are the optimal EC2 instance types for a 3-node Kubernetes learning cluster?

**Findings**:
- **Decision**: t3.small for control plane, t3.micro for workers
- **Rationale**: 
  - t3.small (2 vCPU, 2GB RAM) meets minimum requirements for control plane
  - t3.micro (1 vCPU, 1GB RAM) sufficient for worker nodes in learning context
  - Cost-effective: ~$47/month total (under $50 ceiling)
- **Alternatives Considered**:
  - t3.medium: More expensive ($0.0416/hr) - would exceed budget
  - t2 series: Older generation, burstable performance less predictable

### 2. Kubernetes Bootstrap Method

**Research Question**: What is the best bootstrap method for a simple 3-node cluster?

**Findings**:
- **Decision**: kubeadm with cloud-init scripts
- **Rationale**:
  - kubeadm is the official Kubernetes bootstrap tool
  - Cloud-init ensures automated, repeatable initialization
  - Minimal complexity compared to alternatives
- **Alternatives Considered**:
  - kops: More complex, designed for production clusters
  - Rancher RKE: Additional layer of abstraction not needed
  - Manual setup: Violates IaC principle

### 3. CNI (Container Network Interface) Selection

**Research Question**: Which CNI should be used for pod networking?

**Findings**:
- **Decision**: Flannel
- **Rationale**:
  - Simple to deploy and configure
  - VXLAN backend provides encapsulation
  - Low resource overhead
  - Well-documented and widely used
- **Alternatives Considered**:
  - Calico: More complex, policy features not needed for learning
  - Weave: Additional complexity, not necessary
  - Cilium: Advanced features, steep learning curve

### 4. Cloud-init Script Structure

**Research Question**: How should cloud-init scripts be organized for reliability?

**Findings**:
- **Decision**: Separate scripts for control plane and workers
- **Rationale**:
  - Control plane needs kubeadm init
  - Workers need join command and token
  - Separation allows for role-specific configuration
- **Key Components**:
  - Install container runtime (containerd)
  - Install kubeadm, kubelet, kubectl
  - Configure systemd for services
  - Handle failures with proper logging

### 5. Security Group Configuration

**Research Question**: What security group rules are needed for Kubernetes?

**Findings**:
- **Decision**: Use existing VPC security groups from Spec 001
- **Rationale**:
  - Reuses established network foundation
  - Maintains consistency with existing infrastructure
  - Avoids security group proliferation
- **Required Rules**:
  - Control plane: API server access (6443), etcd (2379-2380), kubelet (10250)
  - Workers: NodePort (30000-32767), kubelet (10250)
  - All nodes: SSH (22), VXLAN (4789 UDP)

### 6. Manual Validation Approach

**Research Question**: How to implement manual validation per constitution?

**Findings**:
- **Decision**: Documentation-based validation with step-by-step guide
- **Rationale**:
  - Aligns with Manual Validation Philosophy
  - No automated testing infrastructure needed
  - Focus on learning and understanding
- **Validation Steps**:
  - Instance status verification
  - Cluster node status check
  - Pod networking test
  - Service discovery validation

## Implementation Decisions Summary

1. **Infrastructure**: Terraform modules for EC2, security groups, and outputs
2. **Bootstrap**: kubeadm with cloud-init scripts
3. **Networking**: Flannel CNI with VXLAN backend
4. **Validation**: Manual verification documentation
5. **Cost Control**: t3.small + 2×t3.micro instances

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Cloud-init script failures | Comprehensive logging and troubleshooting documentation |
| Bootstrap timeouts | Retry mechanisms and timeout handling in scripts |
| Network connectivity issues | VPC security group validation and connectivity testing |
| Resource constraints | Monitoring and upgrade path documentation |

## Dependencies

- Spec 001: VPC Networking Foundation (provides network infrastructure)
- Spec 002: Secure Deployment Foundation (provides security context)
- AWS CLI/Console: For manual validation steps
- kubectl: For cluster verification (post-deployment)