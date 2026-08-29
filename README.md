# SDD Infrastructure Repository

**Self-Deployed DevOps Infrastructure** - A comprehensive, learning-focused infrastructure repository that builds a complete, self-managed Kubernetes cluster on AWS EC2 using kubeadm.

> **Note**: This is a learning project with a budget ceiling of $50/month. All complexity must be justified and documented.

## 🎯 Project Overview

The SDD Infrastructure project implements Infrastructure as Code principles with Terraform as the source of truth, emphasizing security, cost optimization, and manual validation approaches.

### Core Principles
- **Infrastructure as Code First**: All infrastructure declared in Terraform, no manual AWS console operations
- **Cost-Optimized Learning**: Budget ceiling of $50/month, complexity justified and documented
- **Kubernetes as Platform**: Cluster provisioning is separate from application deployment
- **Security Defaults**: IAM roles manually provisioned, secrets in AWS Secrets Manager, encrypted inter-node communication
- **Manual Validation Philosophy**: AWS-first validation, requirements emerge from failures

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    SDD Infrastructure Architecture          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Spec 001: VPC Networking                                   │
│  ├── VPC (10.0.0.0/16)                                     │
│  ├── Public Subnet (10.0.1.0/24)                           │
│  ├── Private Subnets (10.0.2.0/24, 10.0.3.0/24)          │
│  └── Security Groups                                       │
│                                                             │
│  Spec 003: Kubernetes Cluster                               │
│  ├── EC2 Instances (1 control plane, 2 workers)           │
│  ├── kubeadm Bootstrap                                     │
│  └── Flannel CNI                                           │
│                                                             │
│  Spec 005: Application Infrastructure                       │
│  ├── EBS CSI Driver                                        │
│  ├── NGINX Ingress Controller                              │
│  ├── cert-manager                                          │
│  └── Storage Classes                                       │
│                                                             │
│  Spec 002: Secure Deployment Foundation (Cross-cutting)     │
│  ├── GitHub Actions with OIDC                              │
│  ├── Remote State (S3)                                     │
│  └── IAM Roles (manual)                                    │
│                                                             │
│  Spec 004: Destroy Pipeline (Operational)                  │
│  └── Manual Dev Environment Destruction                     │
│                                                             │
│  Spec 009: S3 State Unlock (Operational)                    │
│  └── Emergency State Lock Recovery                          │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Repository Structure

```
.
├── specs/                           # Feature specifications
│   ├── 001-vpc-networking-foundation/     ✅ COMPLETED
│   ├── 002-secure-deployment-foundation/  ✅ COMPLETED
│   ├── 003-kubernetes-cluster-foundation/  ✅ COMPLETED
│   ├── 004-destroy-pipeline/               ✅ COMPLETED
│   ├── 005-application-infrastructure-foundation/ 🔄 IN PROGRESS
│   └── 006-application-deployment-pipeline/ 📋 PLANNED
├── src/
│   └── terraform/                    # Terraform configurations
│       ├── environments/             # Environment-specific configs (dev/prod)
│       └── modules/                 # Reusable modules
│           ├── networking/          # VPC, subnets, security groups
│           ├── kubernetes/          # EC2 instances, kubeadm bootstrap
│           ├── application-infrastructure/ # EBS CSI, ingress, cert-manager
│           └── state/               # Remote state configuration
├── scripts/                         # Operational scripts
│   ├── deploy-application.sh        # Application deployment
│   ├── validate-deployment.sh       # Health validation
│   ├── rollback-deployment.sh       # Rollback procedures
│   ├── validate-connectivity.sh     # Network testing
│   └── [other validation scripts]   # Various health checks
├── docs/                           # Documentation
├── .github/
│   └── workflows/                  # GitHub Actions CI/CD
├── .coda/                         # Coda agent configuration
│   ├── skills/                    # Project skills
│   ├── extensions/                # Extensions
│   └── MEMORY.md                  # Project memory
└── summary.md                     # Comprehensive project summary
```

## 🚀 Current Implementation Status

### ✅ Completed Specifications

#### **Spec 001 - VPC Networking Foundation**
- VPC with configurable CIDR (10.0.0.0/16)
- 1 public subnet (10.0.1.0/24) for control plane and ingress
- 2 private subnets (10.0.2.0/24, 10.0.3.0/24) for worker nodes
- Internet gateway, route tables, and security groups
- **Location**: `src/terraform/modules/networking/`

#### **Spec 002 - Secure Deployment Foundation**
- GitHub Actions workflows with OIDC authentication
- Least-privilege IAM roles (manually provisioned)
- Remote Terraform state with S3 locking
- Support for dev and prod environments (staging removed)
- **Key Decision**: IAM roles manually provisioned to avoid circular dependencies

#### **Spec 003 - Kubernetes Cluster Foundation**
- 3 EC2 instances (1 control plane, 2 workers)
- kubeadm bootstrap for cluster initialization
- Flannel CNI for container networking
- Automatic node joining without manual configuration
- **Location**: `src/terraform/modules/kubernetes/`

#### **Spec 004 - Destroy Pipeline**
- Manual trigger via GitHub Actions workflow dispatch
- Safety confirmations and dry-run capabilities
- Complete resource termination with audit logging
- 10-minute destruction timeout
- **Location**: `.github/workflows/destroy-dev-environment.yml`

### 🔄 In Progress

#### **Spec 005 - Application Infrastructure Foundation**
- EBS CSI driver for persistent storage
- NGINX Ingress controller for external access
- cert-manager for SSL/TLS with Let's Encrypt
- Storage classes for different EBS volume types
- Path-based routing (SPA at root, API at /api/*)
- **Location**: `src/terraform/modules/application-infrastructure/`

### 📋 Planned

#### **Spec 006 - Application Deployment Pipeline**
- CI/CD automation for application workloads
- Environment management (dev/prod)
- Health checks and rollback procedures

## 🛠️ Agent Interaction Guide

### For Future Coda Agents

This repository is designed to be **agent-friendly**. When working with this project:

#### **Understanding the Project Philosophy**
1. **Manual Validation**: This project uses manual validation, not automated tests (per constitutional amendment)
2. **Learning Focus**: All complexity must be justified and documented
3. **Security First**: IAM roles are manually provisioned, not managed by Terraform
4. **Cost Conscious**: $50/month budget ceiling

#### **Key Architectural Decisions**
- **No EKS**: Self-managed Kubernetes on EC2 using kubeadm
- **No Staging**: Only dev and prod environments
- **Manual IAM**: IAM roles and OIDC provider are manually provisioned
- **Push-based CD**: From ECR triggers, not GitOps/ArgoCD

#### **Working with Specifications**
- Each spec has its own directory under `specs/`
- Follow the established pattern: spec.md, plan.md, tasks.md
- Check `MEMORY.md` for important decisions and preferences
- Use the speckit skills for spec management

#### **Module Dependencies**
```
networking → kubernetes → application-infrastructure → application-deployment
```

Always respect the dependency order when making changes.

#### **kubectl Requirements**
kubectl is the **primary operational interface** for this project:
- **Configuration**: kubeconfig must be available at `~/.kube/config`
- **Version**: Must match Kubernetes API server version (±1 minor version)
- **Namespace Strategy**: `demo-apps` for applications, system namespaces for infrastructure
- **Authentication**: Uses AWS IAM authenticator

#### **Common Agent Tasks**

**When implementing new specs:**
1. Check `MEMORY.md` for existing decisions
2. Follow the established spec structure
3. Use the speckit skills for consistency
4. Update relevant documentation

**When troubleshooting:**
1. Check the validation scripts in `scripts/`
2. Review the appropriate spec documentation
3. Use kubectl for cluster operations
4. Check GitHub Actions workflow logs

**When making infrastructure changes:**
1. Understand the module dependencies
2. Test in dev environment first
3. Use Terraform workspaces for environment isolation
4. Document all changes

#### **Important Files to Check**
- `MEMORY.md` - Project memory and decisions
- `summary.md` - Comprehensive project overview
- `specs/` - Current specifications and plans
- `scripts/` - Operational procedures
- `.coda/` - Agent configuration and skills

#### **Security Considerations**
- Never commit secrets or credentials
- Use AWS Secrets Manager for sensitive data
- Respect IAM role boundaries
- Follow the principle of least privilege

## 🚦 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl configured (version compatible with cluster)
- Terraform >= 1.5
- GitHub repository access
- **Budget awareness**: $50/month limit

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone git@github.com:vijote/sdd-iac-infra.git
   cd sdd-infra
   ```

2. **Configure AWS credentials**:
   ```bash
   aws configure
   ```

3. **Set up kubectl** (after cluster creation):
   ```bash
   # Note: This is NOT an EKS cluster - use the kubeadm-provided kubeconfig
   export KUBECONFIG=~/.kube/config
   ```

### Deployment Sequence

**Follow this exact order**:

1. **VPC and Networking** (Spec 001):
   ```bash
   cd src/terraform/environments/dev
   terraform init
   terraform apply -target=module.networking
   ```

2. **Kubernetes Cluster** (Spec 003):
   ```bash
   terraform apply -target=module.kubernetes
   ```

3. **Application Infrastructure** (Spec 005):
   ```bash
   terraform apply -target=module.application-infrastructure
   ```

4. **Complete Deployment**:
   ```bash
   terraform apply
   ```

### Validation

Use the provided validation scripts:
```bash
# Check cluster health
./scripts/health-checks.sh

# Validate deployment
./scripts/validate-deployment.sh dev $(date +%s)

# Test connectivity
./scripts/validate-connectivity.sh
```

## 📚 Documentation

### Key Documents
- [summary.md](summary.md) - Comprehensive project summary
- [MEMORY.md](.coda/MEMORY.md) - Project memory and decisions
- Individual spec documentation in `specs/` directories

### Specifications
Each feature has detailed specifications including:
- User stories and acceptance criteria
- Technical requirements
- Implementation plans
- Validation procedures

## 🔧 Operations

### Common Tasks

**Destroy Dev Environment** (cost control):
```bash
# Via GitHub Actions workflow dispatch
# Or manually:
cd src/terraform/environments/dev
terraform destroy
```

**Application Deployment**:
```bash
./scripts/deploy-application.sh dev $(date +%s)
```

**Rollback Deployment**:
```bash
./scripts/rollback-deployment.sh dev
```

**Resource Monitoring**:
```bash
./scripts/metrics.sh
./scripts/monitor-resources.sh
```

## 🔒 Security

### Authentication
- GitHub OIDC for AWS authentication
- No long-lived credentials
- Role-based access control
- Manually provisioned IAM roles

### Network Security
- VPC with private subnets
- Security groups and NACLs
- Encrypted inter-node communication

### Secrets Management
- AWS Secrets Manager
- Kubernetes secrets
- Encrypted at rest and in transit

## 🚨 Emergency Procedures

### Cost Control
- Use the destroy pipeline (Spec 004) for dev environment
- Monitor resource usage regularly
- Budget alerts configured at $40/month

### State Lock Recovery
- Use the "Unlock Terraform State" workflow (Spec 009) when Terraform workflows are cancelled mid-execution
- Trigger via GitHub Actions workflow dispatch with bucket and state_key parameters
- Removes stale S3 state locks to allow subsequent deployments
- Requires AWS credentials with S3 permissions on lock objects

### Incident Response
1. Check validation scripts outputs
2. Review GitHub Actions logs
3. Use rollback procedures if needed
4. Contact DevOps team for critical issues

## 📈 Project Evolution

The project has evolved from basic infrastructure toward a complete application platform:

1. **Foundation** (001-003): Network → Security → Compute → Cluster
2. **Operations** (004): Cost control via destruction pipeline
3. **Application Layer** (005-006): Infrastructure foundation → Deployment pipeline
4. **Future** (007+): Advanced features and optimizations

## 🤝 Contributing

1. Create a feature branch from `main`
2. Make changes in appropriate spec directory
3. Update documentation and MEMORY.md if needed
4. Submit pull request with detailed description
5. Request review and approval

## 📞 Support

### Getting Help
1. Check [summary.md](summary.md) for comprehensive overview
2. Review relevant specification in `specs/`
3. Run validation scripts for diagnostics
4. Check [MEMORY.md](.coda/MEMORY.md) for project decisions

### Reporting Issues
1. Check existing issues and documentation
2. Create new issue with:
   - Description of problem
   - Steps to reproduce
   - Environment details
   - Error messages/logs
   - Impact on budget/timeline

---

**Last Updated**: 2026-08-29  
**Project Status**: Active Development (Spec 005 in progress)  
**Budget**: $50/month  
**Next Milestone**: Complete Application Infrastructure Foundation

> **For Agents**: This README serves as your primary guide. Always check MEMORY.md for project-specific decisions and preferences before making changes.