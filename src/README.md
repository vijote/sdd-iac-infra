# SDD-Infra Provisioning & Configuration

This directory contains all infrastructure provisioning code and Kubernetes configuration for the self-managed Kubernetes cluster on AWS.

---

## Structure

```
src/
├── terraform/              # Infrastructure as Code (Terraform)
│   ├── modules/           # Reusable Terraform modules
│   │   ├── networking/    # VPC, subnets, security groups (Spec 001)
│   │   ├── iam/           # IAM roles & policies (Spec 002)
│   │   ├── state/         # Remote state management (Spec 002)
│   │   ├── compute/       # EC2 instances & kubeadm bootstrap (Spec 003)
│   │   └── (future phases)
│   ├── environments/      # Environment-specific configurations
│   │   ├── dev/          # Development environment
│   │   ├── staging/      # Staging environment
│   │   ├── prod/         # Production environment
│   │   ├── aws/          # Real AWS deployment
│   │   └── ministack/    # Local ministack testing
│   └── shared/           # Shared configuration (versions, providers)
│
├── k8s/                   # Kubernetes manifests & Helm charts
│   ├── manifests/        # K8s YAML files (Ingress, Services, ConfigMaps)
│   └── helm/             # Helm chart overrides (e.g., nginx-ingress)
│
└── scripts/              # Helper scripts
    ├── deploy.sh        # Main deployment orchestration
    ├── validate.sh      # Validation & testing
    └── cloud-init/      # Cloud-init bootstrap scripts
```

---

## Scaffolding Specs

The foundation is built in three scaffolding specs, each with clear dependencies and success criteria:

### Phase 1: Foundation (Weeks 1-2)

1. **Scaffolding Spec 001: VPC & Networking Foundation**
   - Location: `.coda/docs/SCAFFOLDING_SPEC_001_NETWORKING.md`
   - Module: `src/terraform/modules/networking/`
   - Creates: VPC, subnets, security groups, route tables
   - Status: Ready for implementation

2. **Scaffolding Spec 002: IAM Roles & Policies**
   - Location: `.coda/docs/SCAFFOLDING_SPEC_002_IAM_ROLES.md`
   - Module: `src/terraform/modules/iam/`
   - Creates: EC2 instance roles, pod service account roles
   - Status: Ready for implementation
   - Depends on: Nothing (can run in parallel with Spec 001)

3. **Scaffolding Spec 003: EC2 Instances & kubeadm Bootstrap**
   - Location: `.coda/docs/SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md`
   - Module: `src/terraform/modules/compute/`
   - Creates: EC2 instances, cloud-init bootstrap scripts, kubeadm initialization
   - Status: Ready for implementation
   - Depends on: Specs 001 & 002

---

## Quick Start

### Prerequisites

- Terraform 1.0+ installed
- AWS CLI configured with credentials
- `kubectl` installed locally
- SSH key for EC2 access (optional, for debugging)

### Deploy Phase 1 (Foundation)

```bash
# Navigate to AWS environment
cd src/terraform/environments/aws

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (all three specs together)
terraform apply
```

### Verify Cluster Health

```bash
# Wait 5-10 minutes for bootstrap to complete

# Retrieve kubeconfig from control plane
# (Command depends on how you access the control plane; see AWS docs)

# Verify nodes are ready
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
# Expected: 1 control plane (Ready) + 2 workers (Ready)

# Verify system pods
kubectl get pods -n kube-system
# Expected: All pods Running (Flannel, CoreDNS, kube-proxy, etc.)

# Test pod networking
kubectl run -it --rm debug --image=busybox -- sh
# Inside pod: ping <another-pod-ip> or wget http://10.96.0.10 (CoreDNS)
```

---

## Testing Strategy

### Unit Testing (Local, No AWS)

```bash
cd src/terraform/environments/aws

# Validate Terraform syntax
terraform validate

# Plan and review (no actual changes)
terraform plan -out=tfplan
terraform show tfplan  # Review before applying
```

### Integration Testing (AWS Sandbox)

Each scaffolding spec includes explicit testing instructions:

1. **Spec 001 (Networking):** Verify VPC, subnets, security groups exist
2. **Spec 002 (IAM):** Verify roles and policies are correct
3. **Spec 003 (Compute):** Verify cluster boots, nodes ready, pods running

See `.coda/docs/SCAFFOLDING_SPEC_00X_*.md` for detailed testing steps.

### Ministack Testing (Optional Local)

For fast feedback on Terraform syntax:

```bash
cd src/terraform/environments/ministack
terraform plan  # Validate without deploying
```

Note: Ministack doesn't support AWS services (IAM, Secrets Manager, Route53), so full integration testing requires AWS.

---

## Cost Tracking

Phase 1 (Foundation) estimated monthly cost: **< $25 USD**

- VPC, subnets, security groups: ~$0
- IAM roles & policies: ~$0
- EC2 instances: ~$15-20 (1 t3.small + 2 t3.micro + EBS)
- Data transfer: ~$0 (minimal, within free tier)

Monitor actual costs via AWS Cost Explorer after deployment.

---

## Troubleshooting

### Control Plane Bootstrap Fails

1. Check cloud-init logs: `aws ec2 get-console-output --instance-id <cp-instance-id>`
2. Verify security groups allow necessary ports (6443, 2379-2380, 4789)
3. Verify IAM instance role has permissions to access AWS APIs
4. Re-run `terraform apply` to retry bootstrap

### Nodes Not Joining Cluster

1. Verify worker security group allows traffic from control plane (port 10250, UDP 4789)
2. Check kubelet logs on worker: `journalctl -u kubelet -n 50`
3. Verify join token is valid (expires after 24 hours)

### Pod-to-Pod Networking Broken

1. Verify Flannel is deployed: `kubectl get ds -n kube-system flannel`
2. Check Flannel logs: `kubectl logs -n kube-system <flannel-pod>`
3. Verify VXLAN allowed in security groups (UDP 4789)

For more detailed troubleshooting, see the official kubeadm docs: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/

---

## Environments

### AWS (Real Deployment)

Location: `src/terraform/environments/aws/`

- **Provider:** AWS (EC2, VPC, Route53, Secrets Manager, IAM)
- **Backend:** Remote S3 + DynamoDB (recommended for production state management)
- **Variables:** `terraform.tfvars` (create from `terraform.tfvars.example`)

Deploy with:
```bash
cd src/terraform/environments/aws
terraform init
terraform apply
```

### Ministack (Local Testing)

Location: `src/terraform/environments/ministack/`

- **Provider:** Ministack (local K8s cluster or compatible local provider)
- **Backend:** Local state file
- **Variables:** `terraform.tfvars` (ministack-specific values)

Deploy with:
```bash
cd src/terraform/environments/ministack
terraform init
terraform plan  # Validate syntax
```

---

## Next Phases

After Phase 1 is complete and validated:

- **Phase 2 (Networking):** nginx-ingress, Route53, load balancer
- **Phase 3 (Security):** AWS Secrets Manager, IRSA pod roles
- **Phase 4+ (Future):** Monitoring, logging, additional ingress patterns

Each phase will have its own scaffolding specs, modules, and documentation.

---

## Decision Log

For the reasoning behind architectural choices (VPC CIDR, instance sizes, networking approach, etc.), see:
- `.coda/docs/SPECIFICATION.md` — Overall project spec
- `.coda/docs/DECISION_LOG.md` — Major decisions (D001-D007)
- `.coda/docs/SCAFFOLDING_DECISION_LOG.md` — Phase 1 scaffolding decisions

---

## Contributing

### Code Standards

- **Terraform:** Must pass `terraform fmt` and `terraform validate`
- **Scripts:** Must be executable and well-commented
- **K8s Manifests:** Valid YAML, include resource requests/limits

### Review Checklist

Before merging:
- [ ] Terraform validates without errors
- [ ] `terraform plan` output reviewed and saved in PR
- [ ] Security groups follow least-privilege principle
- [ ] IAM policies are scoped appropriately
- [ ] Cost estimate is within budget (<$50/month)
- [ ] Documentation updated (comments, README, decision log)

---

## 🚀 Deployment Guide

### Prerequisites

1. **AWS Account**: With appropriate permissions for Terraform operations
2. **GitHub Repository**: With Actions enabled
3. **Repository Secrets**: Configure required secrets (see [Repository Secrets Guide](../../docs/repository-secrets-guide.md))

### Automated Deployment (Recommended)

The project uses GitHub Actions for automated deployments with OIDC authentication:

1. **Development**: 
   - Create a pull request → triggers `terraform plan`
   - Merge to main → triggers `terraform apply` to dev environment

2. **Staging**: 
   - Manual workflow execution with environment selection
   - Optional approval based on `STAGING_APPROVAL_REQUIRED` secret

3. **Production**: 
   - Manual workflow execution with environment selection
   - **Mandatory approval** required before apply

### Manual Deployment

For local development or troubleshooting:

```bash
# Navigate to environment directory
cd src/terraform/environments/dev

# Initialize Terraform
terraform init

# Plan changes
terraform plan -var-file="terraform.tfvars"

# Apply changes
terraform apply -var-file="terraform.tfvars"
```

### Environment Configuration

Each environment has its own configuration:
- **Dev**: Automatic deployment, minimal approvals
- **Staging**: Optional approvals, extended testing
- **Prod**: Mandatory approvals, enhanced monitoring

### Security Features

- **OIDC Authentication**: No static AWS credentials stored
- **Least Privilege IAM**: Environment-specific roles with minimal permissions
- **State Locking**: Prevents concurrent state modifications
- **Audit Logging**: Complete audit trail via CloudTrail

### Monitoring & Troubleshooting

- **GitHub Actions**: Check workflow logs for deployment status
- **AWS CloudTrail**: Review API calls and authentication events
- **Terraform State**: Inspect state files for resource status
- See [Troubleshooting Guide](../../docs/troubleshooting-guide.md) for common issues

---

## Support & Questions

For questions about:
- **Terraform structure:** See inline comments in `.tf` files
- **Kubernetes setup:** See cloud-init scripts in `src/terraform/modules/compute/cloud-init/`
- **Architecture decisions:** See decision logs in `.coda/docs/`
- **AWS permissions:** See IAM policies in `src/terraform/modules/iam/`

---

**Last Updated:** 2026-08-20  
**Status:** Phase 1 Scaffolding Specs Ready for Implementation
