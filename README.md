# SDD Infrastructure Repository

This repository contains the infrastructure as code (IaC) and deployment configurations for the Software Development Department (SDD) applications.

## Overview

The infrastructure is built using:
- **Terraform** for infrastructure provisioning
- **Kubernetes** for container orchestration
- **GitHub Actions** for CI/CD pipelines
- **AWS** as the cloud provider

## Repository Structure

```
.
├── specs/                    # Feature specifications
│   ├── 001-vpc-networking-foundation/
│   ├── 002-secure-deployment-foundation/
│   ├── 003-kubernetes-cluster-foundation/
│   ├── 004-destroy-pipeline/
│   ├── 005-application-deployment/
│   ├── 006-application-deployment-pipeline/
│   ├── 006-build-time-secrets/
│   └── 007-ingress-controller/
├── src/
│   └── terraform/           # Terraform configurations
│       ├── environments/    # Environment-specific configs
│       └── modules/         # Reusable modules
├── scripts/                 # Deployment and utility scripts
├── docs/                    # Documentation
├── .github/
│   ├── workflows/          # GitHub Actions workflows
│   └── environments/       # Environment configurations
└── .specify/               # Spec-kit configuration
```

## Quick Start

### Prerequisites

- AWS CLI configured
- kubectl configured
- Terraform >= 1.5
- GitHub repository access

### Initial Setup

1. Clone the repository:
   ```bash
   git clone git@github.com:your-org/sdd-infra.git
   cd sdd-infra
   ```

2. Configure AWS credentials:
   ```bash
   aws configure
   ```

3. Set up kubectl:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name sdd-cluster
   ```

### Deploy Infrastructure

1. **VPC and Networking** (Spec 001):
   ```bash
   cd src/terraform/environments/dev
   terraform init
   terraform apply
   ```

2. **Kubernetes Cluster** (Spec 003):
   ```bash
   cd ../003-kubernetes-cluster
   terraform init
   terraform apply
   ```

3. **Application Infrastructure** (Spec 005):
   ```bash
   cd ../005-application-deployment
   terraform init
   terraform apply
   ```

### Deploy Applications

Use the Application Deployment Pipeline (Spec 006):

1. **Automatic Deployment** (Dev):
   - Push to main branch
   - Pipeline auto-deploys to dev

2. **Manual Deployment**:
   ```bash
   # Trigger via GitHub Actions
   # Or use the deployment script
   ./scripts/deploy-application.sh dev $(date +%s)
   ```

## Documentation

### Key Documents

- [Pipeline Guide](docs/pipeline-guide.md) - Complete pipeline documentation
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions
- [Operations Runbook](docs/runbook.md) - Operational procedures
- [Architecture Overview](docs/architecture.md) - System architecture

### Specifications

Each feature has its own specification in the `specs/` directory:
- **001**: VPC and networking foundation
- **002**: Secure deployment foundation
- **003**: Kubernetes cluster foundation
- **004**: Destroy pipeline
- **005**: Application deployment infrastructure
- **006**: Application deployment pipeline
- **007**: Build-time secrets manager
- **008**: Ingress controller

## Environments

### Development Environment
- **Purpose**: Development and testing
- **Auto-deploy**: Enabled
- **Approval**: Not required
- **Resources**: Optimized for cost

### Production Environment
- **Purpose**: Production workloads
- **Auto-deploy**: Disabled
- **Approval**: Required
- **Resources**: Optimized for performance

## CI/CD Pipeline

The Application Deployment Pipeline provides:

- **Automated deployment** on code changes
- **Environment-specific** configurations
- **Health checks** and validation
- **Automatic rollback** on failure
- **Approval workflows** for production

### Pipeline Stages

1. **Validate** - Configuration and prerequisites
2. **Deploy Infrastructure** - Terraform changes
3. **Deploy Applications** - Kubernetes deployments
4. **Validate Deployment** - Health checks

## Security

### Authentication
- GitHub OIDC for AWS authentication
- No long-lived credentials
- Role-based access control

### Network Security
- VPC with private subnets
- Security groups and NACLs
- Network policies in Kubernetes

### Secrets Management
- AWS Secrets Manager
- Kubernetes secrets
- Encrypted at rest and in transit

## Monitoring

### Metrics Collected
- Deployment success rate
- Resource utilization
- Application performance
- Error rates

### Alerting
- High error rates
- Resource limits exceeded
- Deployment failures
- Health check failures

## Contributing

1. Create a feature branch
2. Make changes in appropriate spec directory
3. Update documentation
4. Submit pull request
5. Request review and approval

## Support

### Getting Help
- Check [troubleshooting guide](docs/troubleshooting.md)
- Review [runbook](docs/runbook.md)
- Contact DevOps team

### Reporting Issues
1. Check existing issues
2. Create new issue with:
   - Description of problem
   - Steps to reproduce
   - Environment details
   - Error messages/logs

## Emergency Contacts

- **DevOps Team**: devops@example.com
- **On-call Engineer**: +1-555-0123
- **Incident Channel**: #incidents

## License

This repository is proprietary to the Software Development Department.

## Version History

- **v1.0.0** - Initial infrastructure setup
- **v1.1.0** - Added Kubernetes cluster
- **v1.2.0** - Added application deployment
- **v1.3.0** - Added CI/CD pipeline
- **v1.4.0** - Added monitoring and alerting

---

For detailed information, see the [documentation](docs/) directory.