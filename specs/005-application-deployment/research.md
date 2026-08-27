# Research: Application Deployment Infrastructure

**Date**: 2026-08-27  
**Feature**: Application Deployment Infrastructure  
**Phase**: 0 - Research & Decision Making

## Research Tasks & Findings

### 1. EBS Storage Configuration for MySQL

**Research Question**: What EBS storage type and configuration is optimal for MySQL within t3.micro/t3.small constraints?

**Decision**: Use gp3 EBS volumes with:
- 20GB storage (sufficient for demo)
- 3000 IOPS (included in gp3 base)
- 125 MB/s throughput (included in gp3 base)
- Encryption enabled (security requirement)

**Rationale**: 
- gp3 provides better price/performance than gp2
- Base performance is adequate for demo workload
- Stays within budget constraints
- Meets security encryption requirements

**Alternatives Considered**:
- gp2: Higher cost for same performance
- io1: Too expensive for demo purposes
- io2: Overkill for demo workload

### 2. Resource Limits for Demo Applications

**Research Question**: What CPU/memory limits are appropriate for each application within t3.micro/t3.small constraints?

**Decision**:
- SPA (nginx): 100m CPU, 128Mi memory
- NodeJS backend: 200m CPU, 256Mi memory  
- MySQL: 300m CPU, 512Mi memory

**Rationale**:
- Total fits within t3.small (2 vCPU, 2GiB memory)
- Leaves headroom for Kubernetes system components
- Sufficient for demo traffic
- Allows for some burst capacity

**Alternatives Considered**:
- Higher limits: Would exceed instance capacity
- Lower limits: Poor performance for demo

### 3. Ingress Controller Integration

**Research Question**: How to integrate with nginx-ingress from Spec 007?

**Decision**: Use standard Kubernetes Ingress resources with:
- Path-based routing (/api/* → backend, /* → frontend)
- TLS termination at ingress level
- Annotations for nginx configuration

**Rationale**:
- Standard Kubernetes pattern
- Leverages existing nginx-ingress deployment
- Simple and maintainable
- Supports future scaling

**Alternatives Considered**:
- Service of type LoadBalancer: Higher cost, unnecessary complexity
- Istio gateway: Overkill for demo

### 4. Secrets Management Integration

**Research Question**: How to integrate with AWS Secrets Manager from Spec 006?

**Decision**: Use Kubernetes External Secrets operator to:
- Sync AWS Secrets Manager secrets to Kubernetes secrets
- Automatic rotation support
- IAM role for service account (IRSA) for secure access

**Rationale**:
- Follows security best practices
- No secrets in code or git
- Automatic sync reduces manual work
- IRSA provides secure credential management

**Alternatives Considered**:
- Manual secret creation: Error-prone, no rotation
- HashiCorp Vault: Additional complexity, not needed

### 5. Health Check Implementation

**Research Question**: What health check endpoints are needed for each application?

**Decision**:
- SPA: /health endpoint returning static "OK"
- NodeJS: /health endpoint checking database connectivity
- MySQL: Kubernetes native TCP probe on port 3306

**Rationale**:
- Simple and reliable
- Covers application and database connectivity
- Standard Kubernetes patterns

**Alternatives Considered**:
- Complex health checks: Overkill for demo
- No health checks: Violates requirements

### 6. Configuration Management Strategy

**Research Question**: How to manage environment-specific configurations?

**Decision**: 
- Use ConfigMaps for non-sensitive config (API URLs, feature flags)
- Use Secrets for sensitive data (passwords, API keys)
- Environment-specific values in Terraform tfvars files

**Rationale**:
- Clear separation of concerns
- Supports dev/prod environments
- Follows Kubernetes best practices
- Meets security requirements

**Alternatives Considered**:
- All config in environment variables: Harder to manage
- All config in files: Less flexible for overrides

## Summary of Decisions

All research questions have been resolved with decisions that:
1. Respect the $50/month budget constraint
2. Work within t3.micro/t3.small resource limits
3. Follow security best practices
4. Use standard Kubernetes patterns
5. Support the manual validation philosophy
6. Integrate properly with dependent specs (003, 006, 007)

No NEEDS CLARIFICATION items remain. Ready to proceed to Phase 1 design.