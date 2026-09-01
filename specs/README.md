# `specs/` — Feature Specifications

This directory contains all feature specifications for the SDD Infrastructure project. Each spec is a self-contained directory that documents the **user stories, requirements, implementation plan, and task breakdown** for one feature.

## Spec Overview

| Spec | Name | Status | Description |
|------|------|--------|-------------|
| [001](001-vpc-networking-foundation/) | VPC Networking Foundation | ✅ Complete | VPC, subnets, internet gateway, security groups |
| [002](002-secure-deployment-foundation/) | Secure Deployment Foundation | ✅ Complete | GitHub Actions OIDC, IAM roles, remote Terraform state |
| [003](003-kubernetes-cluster-foundation/) | Kubernetes Cluster Foundation | ✅ Complete | EC2 instances, kubeadm bootstrap, Flannel CNI |
| [004](004-destroy-pipeline/) | Destroy Pipeline | ✅ Complete | Manual dev environment teardown workflow |
| [005](005-application-infrastructure-foundation/) | Application Infrastructure Foundation | 🔄 In Progress | EBS CSI, NGINX Ingress, cert-manager, storage classes |
| [006-pipeline](006-application-deployment-pipeline/) | Application Deployment Pipeline | 📋 Planned | CI/CD pipeline for application workloads |
| [006-secrets](006-build-time-secrets/) | Build-time Secrets Manager | 📋 Planned | AWS Secrets Manager integration at build time |
| [007](007-ingress-controller/) | Ingress Controller Integration | 📋 Planned | NGINX ingress + Route53 DNS integration |
| [009](009-s3-state-unlock/) | S3 State Unlock | ✅ Complete | Emergency workflow to clear stale Terraform state locks |

## Standard Spec Structure

Each spec directory follows a consistent layout:

| File | Description |
|------|-------------|
| `spec.md` | User stories, acceptance criteria, functional requirements, and success criteria |
| `plan.md` | Step-by-step implementation plan |
| `tasks.md` | Granular task breakdown with status tracking |
| `quickstart.md` | How to use / validate the feature quickly |
| `research.md` | Background research and technology decisions |
| `data-model.md` | Data model and key entities |
| `checklists/` | Pre-deployment and validation checklists |
| `contracts/` | Interface contracts between this spec and others |

## Dependency Order

```
001 (VPC) → 002 (IAM/CI-CD) → 003 (Kubernetes) → 005 (App Infra) → 006 (Deployment)
                                                  ↗
                                 004 (Destroy)   007 (Ingress)
                                 009 (State Unlock)
```
