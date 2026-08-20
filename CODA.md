# SDD-Infra: Self-Managed Kubernetes on AWS

Welcome to the SDD-Infra project! This document serves as the initialization guide for working with this infrastructure-as-code project.

## Quick Start

This project provisions a **self-managed Kubernetes cluster on AWS EC2** using Terraform. It's designed as a learning platform to understand Kubernetes internals while maintaining cost optimization.

### Project Structure

```
sdd-infra/
├── .coda/                    # Coda agent configuration and memory
│   ├── skills/               # Coda skills for project workflows
│   └── MEMORY.md             # Persistent project context
├── .specify/                 # Project specifications and documentation
│   └── memory/               # Organized project documentation
│       ├── INDEX.md          # Documentation index and guide
│       ├── architecture/     # Core architecture documents
│       ├── decisions/        # Decision logs and rationale
│       ├── scaffolding/      # Phase 1 scaffolding specifications
│       ├── phase1/          # Phase 1 implementation guides
│       └── templates/       # Document templates
├── src/                      # Source code and implementations
│   ├── terraform/            # Terraform modules and configurations
│   ├── k8s/                  # Kubernetes manifests
│   └── scripts/              # Utility scripts
├── CODA.md                   # This file - project initialization guide
└── README.md                 # Project overview
```

## Key Documentation

**Start here for understanding the project:**
- **[INDEX.md](.specify/memory/INDEX.md)** - Complete documentation index and guide
- **[SPECIFICATION.md](.specify/memory/architecture/SPECIFICATION.md)** - Complete project specification
- **[CONSTITUTION.md](.specify/memory/architecture/CONSTITUTION.md)** - Project principles and constraints
- **[DECISION_LOG.md](.specify/memory/decisions/DECISION_LOG.md)** - Architectural decisions and rationale

**Phase 1 Implementation (Current):**
- **[PHASE_1_SCAFFOLDING_SUMMARY.md](.specify/memory/phase1/PHASE_1_SCAFFOLDING_SUMMARY.md)** - Overview of current phase
- **[PHASE_1_VISUAL_GUIDE.md](.specify/memory/phase1/PHASE_1_VISUAL_GUIDE.md)** - Visual diagrams and quick reference
- **[SCAFFOLDING_SPEC_001_NETWORKING.md](.specify/memory/scaffolding/SCAFFOLDING_SPEC_001_NETWORKING.md)** - VPC and networking
- **[SCAFFOLDING_SPEC_002_IAM_ROLES.md](.specify/memory/scaffolding/SCAFFOLDING_SPEC_002_IAM_ROLES.md)** - IAM roles and policies
- **[SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md](.specify/memory/scaffolding/SCAFFOLDING_SPEC_003_EC2_BOOTSTRAP.md)** - EC2 instances and kubeadm

## Core Principles

1. **Infrastructure as Code First** - Everything is declared in code, no manual AWS console actions
2. **Terraform is Source of Truth** - All AWS resources defined in Terraform
3. **Declarative Over Imperative** - We describe what infrastructure should be
4. **Minimal & Cost-Optimized** - Learning project with tight budget constraints
5. **Security Defaults** - Least-privilege IAM, secrets management, encrypted communication

## Getting Started

1. **Read the Index** - Start with `.specify/memory/INDEX.md` for complete documentation overview
2. **Read the Specification** - Review `.specify/memory/architecture/SPECIFICATION.md` to understand project goals
3. **Review the Constitution** - Understand the principles in `.specify/memory/architecture/CONSTITUTION.md`
4. **Check Phase 1 Status** - Review `.specify/memory/phase1/PHASE_1_SCAFFOLDING_SUMMARY.md` for current work
5. **Examine Implementation** - Look in `src/terraform/` for current modules

## Development Workflow

- All infrastructure changes must be made through Terraform
- Documentation updates accompany all significant changes
- Use the Coda skills for consistent project workflows
- Follow the decision log process for architectural changes

## Important Rules

- **DO NOT** create documentation files inside `.coda/` - this directory is managed by the Coda agent system
- All project documentation should be created in `.specify/memory/` or appropriate subdirectories
- Use the existing documentation structure and follow established patterns

## Current Status

**Phase 1: Scaffolding** - Building foundational infrastructure modules
- Spec 001: Networking (VPC, subnets, security groups)
- Spec 002: IAM Roles (least-privilege access patterns)  
- Spec 003: EC2 Bootstrap (instances and kubeadm setup)

Check the Phase 1 summary for detailed progress and dependencies.

---

*This project follows strict IAC principles and is designed for learning Kubernetes internals through hands-on infrastructure management.*