# `scripts/` — Operational Scripts

This directory contains **bash shell scripts** for day-to-day operations: deploying, validating, monitoring, and rolling back infrastructure and applications. All scripts are designed to be run from the repository root or with a clearly documented working directory.

## Scripts

### Deployment

| Script | Description |
|--------|-------------|
| [`deploy-application.sh`](deploy-application.sh) | Deploys application workloads to the Kubernetes cluster for a given environment and timestamp |
| [`deploy-apps.sh`](deploy-apps.sh) | Lightweight wrapper that calls `deploy-application.sh` with sensible defaults |
| [`rollback-deployment.sh`](rollback-deployment.sh) | Rolls back application deployments to the previous known-good version |
| [`cleanup-apps.sh`](cleanup-apps.sh) | Removes deployed application resources from the cluster |

### Validation

| Script | Description |
|--------|-------------|
| [`validate-deployment.sh`](validate-deployment.sh) | Validates that a deployment completed successfully (pod health, service endpoints) |
| [`validate-apps.sh`](validate-apps.sh) | Quick application-level validation wrapper |
| [`validate-connectivity.sh`](validate-connectivity.sh) | Tests network connectivity between cluster nodes and to external endpoints |
| [`validate-database.sh`](validate-database.sh) | Validates MySQL database connectivity and schema state |
| [`validate-permissions.sh`](validate-permissions.sh) | Checks that IAM roles and Kubernetes RBAC permissions are correctly configured |
| [`validate-performance.sh`](validate-performance.sh) | Runs performance validation against deployed services |

### Monitoring & Observability

| Script | Description |
|--------|-------------|
| [`health-checks.sh`](health-checks.sh) | Comprehensive cluster and application health checks |
| [`monitor-resources.sh`](monitor-resources.sh) | Monitors AWS resource usage (EC2, EBS, etc.) for cost awareness |
| [`metrics.sh`](metrics.sh) | Collects and displays key application and infrastructure metrics |
| [`check-drift.sh`](check-drift.sh) | Detects drift between actual AWS resources and Terraform state |

### Inventory

| Script | Description |
|--------|-------------|
| [`generate-inventory.sh`](generate-inventory.sh) | Generates a full inventory of deployed AWS resources (used before destroy pipeline) |

## Usage

```bash
# Deploy to dev
./scripts/deploy-application.sh dev $(date +%s)

# Check cluster health
./scripts/health-checks.sh

# Validate deployment
./scripts/validate-deployment.sh dev $(date +%s)

# Rollback
./scripts/rollback-deployment.sh dev
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- `kubectl` configured to point at the target cluster (`~/.kube/config`)
- Bash 4.0+
