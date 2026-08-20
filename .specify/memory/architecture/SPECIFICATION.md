# Specification: Self-Managed Kubernetes on AWS

**Project Name:** Self-Managed Kubernetes Infrastructure (SDD-Infra)  
**Version:** 1.0  
**Date:** 2026-08-20  
**Status:** Active  
**Audience:** Internal learning project

---

## Executive Summary

This project provisions a **self-managed Kubernetes cluster on AWS EC2** to serve as a learning platform and reference architecture. The cluster will run three minimal demo applications (frontend, backend, database) deployed from separate repositories. The infrastructure is fully defined and deployed via Terraform, demonstrating infrastructure-as-code best practices. The primary goals are **learning Kubernetes internals** and **cost optimization** through self-management.

---

## Project Goals

1. **Learning:** Understand Kubernetes architecture, control plane setup, networking, and operational concerns.
2. **Cost Optimization:** Self-managed K8s costs significantly less than managed services (EKS, AKS).
3. **Reproducibility:** Full infrastructure defined in code; deployable in minutes via Terraform.
4. **Internal Reference:** Serve as a template for future internal infrastructure projects.

---

## Scope

### In Scope

#### Infrastructure Provisioning
- AWS VPC, subnets, security groups, and routing tables
- EC2 instance provisioning (1 control plane, 2 worker nodes)
- IAM roles and policies for node communication and AWS integration

#### Kubernetes Setup
- kubeadm-based bootstrap of control plane and worker nodes
- Flannel CNI for pod networking (VXLAN tunneling)
- CoreDNS for in-cluster DNS
- kube-proxy for service networking
- etcd for distributed state management

#### Networking & Ingress
- Single Route53 DNS entry pointing to ingress load balancer
- nginx-ingress controller for HTTP routing
- Path-based routing: `/` → frontend service, `/api` → backend service
- Load balancing across service replicas

#### Storage
- EBS volumes for database persistence (provisioned, not managed by cluster)
- ConfigMaps and Secrets for application configuration

#### Security
- AWS Secrets Manager for storing and rotating secrets
- IAM Service Accounts (IRSA) for pod-to-AWS authentication
- Security group rules for inter-node communication
- VPC isolation

#### CI/CD
- Terraform plan/apply pipeline on Git merge
- Infrastructure validation and deployment automation

### Out of Scope

- **Logging & Observability:** CloudWatch, ELK, or Prometheus not included. Apps must handle their own logs if needed.
- **RBAC (Role-Based Access Control):** Basic Kubernetes RBAC only. Production RBAC policies deferred.
- **Application Deployment:** Apps are deployed from their own repositories using separate tools (sdd). This repo provides the cluster only.
- **Monitoring & Alerting:** No cluster monitoring beyond basic health checks.
- **Disaster Recovery & Backup:** etcd backups and cluster restoration not covered in MVP.

---

## Architecture

### Cluster Topology

```
┌─────────────────────────────────────────────────────────┐
│                      AWS Region (us-east-1)             │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐      ┌──────────────┐                │
│  │ Control Plane│      │  Worker Node 1               │
│  │  (t3.small)  │      │   (t3.micro)  │                │
│  │              │      │               │                │
│  │ - API Server │      │ - kubelet     │                │
│  │ - Scheduler  │      │ - kube-proxy  │                │
│  │ - Controller │      │ - Flannel     │                │
│  │ - etcd       │      │ - 2x app pods │                │
│  └──────────────┘      └──────────────┘                │
│        │                      │                          │
│        └──────────┬───────────┘                         │
│                   │                                      │
│        ┌──────────────────────┐                         │
│        │   Flannel Network    │                         │
│        │  (Pod-to-Pod via     │                         │
│        │   VXLAN Tunnel)      │                         │
│        └──────────────────────┘                         │
│                   │                                      │
│        ┌──────────────────────┐                         │
│        │  nginx-ingress       │                         │
│        │  (ingress controller)│                         │
│        └──────────────────────┘                         │
│                   │                                      │
│        ┌──────────────────────┐                         │
│        │  AWS Load Balancer   │                         │
│        └──────────────────────┘                         │
│                   │                                      │
└──────────────────┼──────────────────────────────────────┘
                   │
        ┌──────────────────────────┐
        │  Route53 DNS Entry       │
        │  (api.example.com)       │
        └──────────────────────────┘
                   │
        ┌──────────────────────────┐
        │     Internet Users        │
        └──────────────────────────┘
```

### Data Flow

1. **User Request:** `GET https://api.example.com/` → Route53 resolves to load balancer.
2. **Ingress Routing:** nginx-ingress inspects path; routes `/` to frontend service, `/api` to backend service.
3. **Service Discovery:** kube-proxy translates service IP to pod IPs; CoreDNS resolves service names.
4. **Pod Communication:** Flannel VXLAN tunnel carries pod traffic across nodes.
5. **Database:** Backend service connects to external EBS-backed database (managed separately).

---

## Technical Requirements

### Functional Requirements

#### Cluster Provisioning
- **FR1:** Terraform provisioning runs end-to-end without manual intervention.
- **FR2:** Control plane initializes via kubeadm; all nodes join the cluster automatically.
- **FR3:** Flannel CNI deploys and all pods can communicate across nodes.
- **FR4:** kube-proxy and CoreDNS functional; service discovery works.

#### Ingress & Routing
- **FR5:** Single Route53 entry resolves to the ingress load balancer.
- **FR6:** Requests to `/` route to frontend service; `/api` routes to backend service.
- **FR7:** nginx-ingress controller is deployed and healthy.

#### Secrets & Configuration
- **FR8:** Terraform provisions secrets in AWS Secrets Manager.
- **FR9:** Pods can authenticate to AWS via IAM Service Accounts and retrieve secrets.
- **FR10:** ConfigMaps for non-sensitive configuration data.

#### Multi-Replica Deployments
- **FR11:** Each app can run with 2 replicas; load balancing distributes traffic.

### Non-Functional Requirements

#### Performance
- **NFR1:** Cluster boots and is ready to accept deployments within 10 minutes of `terraform apply`.
- **NFR2:** Pod-to-pod latency: <10ms (within same region).
- **NFR3:** Service DNS resolution: <100ms.
- **NFR4:** No hard throughput requirements (learning project); minimal apps suffice.

#### Availability
- **NFR5:** Control plane: single instance (no HA). Worker node loss is tolerated if app is replicated.
- **NFR6:** No SLA commitment; acceptable downtime during learning/testing.

#### Security
- **NFR7:** Pods cannot access the EC2 metadata service without proper IAM roles.
- **NFR8:** Inter-node communication encrypted via Flannel VXLAN.
- **NFR9:** AWS credentials never stored in pod ConfigMaps or logs.
- **NFR10:** Security groups restrict traffic to necessary ports only.

#### Cost
- **NFR11:** Total monthly AWS spend <$50 USD (1 t3.small + 2 t3.micro + EBS + data transfer).
- **NFR12:** No premium services (no NAT gateways, minimal data transfer, free-tier usage where possible).

#### Maintainability
- **NFR13:** Terraform code is modular (separate files for VPC, EC2, K8s, ingress).
- **NFR14:** All infrastructure is version-controlled in Git; no manual changes allowed.
- **NFR15:** Cloud-init scripts are documented and reproducible.

---

## Components & Responsibilities

### 1. Terraform (Infrastructure as Code)
**Responsibility:** Provision all AWS resources and configure K8s cluster.

**Deliverables:**
- VPC, subnets, security groups, route tables
- EC2 instances for control plane and workers
- IAM roles and instance profiles
- Route53 DNS records
- EBS volumes for database
- kubeadm bootstrap scripts (via cloud-init)
- nginx-ingress Helm deployment

**Files:**
```
terraform/
├── main.tf              # VPC, subnets, security groups
├── ec2.tf               # EC2 instances, IAM roles
├── kubernetes.tf        # kubeadm bootstrap, Flannel, nginx-ingress
├── networking.tf        # Route53, load balancer
├── secrets.tf           # AWS Secrets Manager
├── variables.tf         # Input variables (instance size, region, etc.)
├── outputs.tf           # Cluster endpoints, kubeconfig, etc.
└── terraform.tfvars     # Environment-specific values
```

### 2. kubeadm & Cloud-Init
**Responsibility:** Bootstrap Kubernetes cluster on EC2 instances.

**Deliverables:**
- Cloud-init scripts to initialize control plane
- Cloud-init scripts to join worker nodes
- Flannel deployment manifest
- CoreDNS configuration

**Embedded in:** EC2 user data and Terraform provisioners.

### 3. AWS Secrets Manager
**Responsibility:** Store and rotate application secrets.

**Deliverables:**
- Secret resources provisioned by Terraform
- IAM policies for pod access via IRSA

### 4. nginx-ingress Controller
**Responsibility:** Route HTTP requests to appropriate services.

**Deliverables:**
- Helm chart deployment (via Terraform)
- Ingress rules for path-based routing
- Integration with AWS load balancer

---

## Deployment Process

### Prerequisites
- AWS account with appropriate permissions
- Terraform CLI installed (v1.0+)
- Git repository with this code

### Deployment Steps

1. **Clone & Configure**
   ```bash
   git clone <repo>
   cd terraform
   # Edit terraform.tfvars for your AWS region, instance types, etc.
   ```

2. **Validate & Plan**
   ```bash
   terraform init
   terraform plan
   # Review changes; ensure they match expectations
   ```

3. **Apply**
   ```bash
   terraform apply
   # Sit back; cluster boots in ~8 minutes
   ```

4. **Verify**
   ```bash
   # Wait for all nodes to be Ready
   kubectl get nodes
   # Check pods are running
   kubectl get pods --all-namespaces
   # Test ingress routing
   curl https://api.example.com/
   ```

5. **Deploy Apps**
   - Apps deployed from their own repos (sdd); outside this repo's scope.

---

## Success Criteria

### Provisioning
- ✅ `terraform apply` completes without errors.
- ✅ All EC2 instances launch and pass status checks.
- ✅ Control plane kubeadm init succeeds.
- ✅ All worker nodes join the cluster.

### Cluster Health
- ✅ `kubectl get nodes` shows 1 control plane + 2 workers in `Ready` state.
- ✅ All kube-system pods are running (CoreDNS, Flannel, kube-proxy, etc.).
- ✅ Pod-to-pod connectivity verified (e.g., `kubectl run -it --rm debug --image=busybox -- sh` and ping another pod).

### Networking & Ingress
- ✅ Route53 entry resolves to the load balancer IP.
- ✅ nginx-ingress is deployed and running.
- ✅ HTTP requests to `/` and `/api` reach the intended services (verified via curl).

### Secrets & IAM
- ✅ Secrets are provisioned in AWS Secrets Manager.
- ✅ Pods can assume IAM roles via IRSA and retrieve secrets.

### Cost Validation
- ✅ AWS billing shows <$50/month estimated cost.

---

## Dependencies & Assumptions

### External Dependencies
- **AWS Account:** With EC2, VPC, Route53, IAM, Secrets Manager, EBS access.
- **AWS CLI & Credentials:** For Terraform to authenticate.
- **kubeadm:** Available in EC2 AMI or installed via cloud-init.
- **Route53 Domain:** Pre-existing Route53 hosted zone.

### Assumptions
- **Network Connectivity:** All nodes can reach AWS APIs (via NAT or public IPs).
- **DNS:** Route53 domain is pre-created and accessible.
- **EBS Availability:** EBS snapshots/volumes available in the target region.
- **App Readiness:** Apps are deployed separately and assume a running K8s cluster.

---

## Risk Assessment & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| Control plane failure (single node) | Medium | Critical | Cluster becomes unavailable. Acceptable for learning; not for production. |
| t3.micro resource exhaustion | Medium | High | Monitor resource usage; upgrade to t3.small if needed. Pre-test with load. |
| kubeadm bootstrap timeout | Low | High | Timeout handled by Terraform; retry logic in cloud-init. |
| Network partition (node leaves cluster) | Low | Medium | Flannel recovers; nodes rejoin. Pods may be rescheduled. |
| Secret rotation (Secrets Manager) | Low | Low | Apps handle secret refresh logic. Terraform manages initial provisioning. |
| Cost overruns | Low | Medium | Monitor AWS billing; scale down instances if needed. No auto-scaling configured. |

---

## Timeline & Phases

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| **Phase 1: Foundation** | Week 1-2 | Terraform scaffolding, VPC, EC2 instances |
| **Phase 2: Kubernetes** | Week 2-3 | kubeadm bootstrap, Flannel, CoreDNS, kube-proxy |
| **Phase 3: Networking** | Week 3-4 | nginx-ingress, Route53 integration, load balancer |
| **Phase 4: Secrets & Security** | Week 4-5 | AWS Secrets Manager, IRSA, IAM policies |
| **Phase 5: Testing & Validation** | Week 5-6 | End-to-end testing, documentation, performance tuning |
| **Phase 6: CI/CD & Handoff** | Week 6-7 | Terraform pipeline, runbook, team training |
| **Buffer** | Week 7-8 | Contingency for issues, improvements, refinement |

---

## Out-of-Scope Clarification

The following are explicitly **NOT** part of this project:

- **Logging Infrastructure:** Apps log to stdout; no centralized log aggregation. CloudWatch/ELK can be added later.
- **RBAC Policies:** Only basic K8s RBAC. Production RBAC rules deferred.
- **Monitoring & Alerting:** No Prometheus, Grafana, or CloudWatch dashboards. Basic health checks only.
- **Disaster Recovery:** No etcd backups or cluster restoration procedures.
- **Application Code:** Apps defined elsewhere; this repo is infrastructure only.
- **Multi-Region:** Single region deployment; multi-region is future work.

---

## Glossary

- **kubeadm:** Bootstrap tool for Kubernetes clusters.
- **Flannel:** Simple, lightweight container network interface (CNI) for Kubernetes.
- **VXLAN:** Virtual Extensible LAN; tunneling protocol used by Flannel.
- **IRSA:** IAM Roles for Service Accounts; allows K8s pods to assume AWS IAM roles.
- **nginx-ingress:** Kubernetes ingress controller using NGINX.
- **Secrets Manager:** AWS service for storing and rotating secrets.
- **EBS:** Elastic Block Store; AWS persistent storage volumes.
- **CoreDNS:** Kubernetes DNS server for service discovery.
- **kube-proxy:** Kubernetes service proxy; implements load balancing rules.

---

## Appendix: Decision Log Reference

For detailed rationale on major decisions (CNI choice, kubeadm approach, instance sizing, etc.), see `.coda/docs/DECISION_LOG.md`.

---

## Sign-Off

- **Author:** Coda  
- **Date:** 2026-08-20  
- **Status:** Ready for Implementation
