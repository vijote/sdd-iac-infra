# Scaffolding Spec 002: IAM Roles & Policies

**Version:** 1.0  
**Date:** 2026-08-20  
**Status:** Ready for Implementation  
**Phase:** Phase 1 (Foundation)  
**Depends On:** Scaffolding Spec 001 (Networking)

---

## Overview

This spec defines **AWS IAM roles, policies, and instance profiles** for EC2 nodes. These roles enable:
1. **Node-to-AWS communication:** EC2 instances can reach AWS APIs (EC2, VPC, Route53, Secrets Manager, etc.)
2. **Secrets access:** Pods can retrieve secrets from AWS Secrets Manager via IAM Service Accounts (IRSA)
3. **Least-privilege enforcement:** Each role has only the permissions it needs

**Goal:** Create reusable IAM Terraform module with clear separation between control plane and worker node roles.

---

## Scope

### In Scope

1. **EC2 Instance Role (Control Plane)**
   - Permissions: Manage cluster infrastructure (EC2 describe, VPC describe, Route53, Secrets Manager)
   - Purpose: kubeadm bootstrap, cluster operations, secret retrieval

2. **EC2 Instance Role (Worker Nodes)**
   - Permissions: Describe instances (for Flannel VXLAN), retrieve secrets
   - Purpose: Node self-registration, pod secret access

3. **IAM Service Account Role (For Pods)**
   - Permissions: Assumed by pods via IRSA; read-only access to Secrets Manager
   - Purpose: Apps retrieve secrets without hardcoding credentials

4. **Instance Profiles**
   - Link IAM roles to EC2 instances; created but not attached in this spec (EC2 spec will attach)

5. **Trust Relationships**
   - Control plane role trusts EC2 service
   - Worker role trusts EC2 service
   - Pod role trusts the Kubernetes OIDC provider (configured in Spec 003)

### Out of Scope

- Advanced IAM conditions (IP-based restrictions, time-based access)
- Cross-account roles (single AWS account only)
- Custom IAM policies for application-specific needs (apps define their own policies)
- KMS key encryption (Secrets Manager uses default AWS-managed keys)

---

## Technical Design

### IAM Roles & Trust Relationships

```
┌─────────────────────────────────────────────┐
│          Control Plane Instance             │
│  (Assumes: ControlPlaneRole)                │
├─────────────────────────────────────────────┤
│ Trust: EC2 Service                          │
│ Permissions:                                │
│  - ec2:DescribeInstances                   │
│  - ec2:DescribeTags                        │
│  - route53:ChangeResourceRecordSets        │
│  - secretsmanager:GetSecretValue           │
│  - secretsmanager:ListSecrets              │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│          Worker Node Instances              │
│  (Assume: WorkerNodeRole)                   │
├─────────────────────────────────────────────┤
│ Trust: EC2 Service                          │
│ Permissions:                                │
│  - ec2:DescribeInstances                   │
│  - ec2:DescribeTags                        │
│  - secretsmanager:GetSecretValue           │
│  - secretsmanager:ListSecrets              │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│          Pod Service Account                │
│  (AssumeRolePolicy via IRSA)                │
├─────────────────────────────────────────────┤
│ Trust: Kubernetes OIDC Provider             │
│        (oidc.eks.amazonaws.com/id/...)    │
│ Permissions:                                │
│  - secretsmanager:GetSecretValue (READ)    │
│  - secretsmanager:ListSecrets              │
└─────────────────────────────────────────────┘
```

### IAM Policy Structure

#### Control Plane Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2Describe",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeRouteTables"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53Manage",
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:GetChange",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*",
        "arn:aws:route53:::change/*"
      ]
    },
    {
      "Sid": "SecretsManagerRead",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecrets",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:sdd-infra/*"
    }
  ]
}
```

#### Worker Node Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2Describe",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecretsManagerRead",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecrets"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:sdd-infra/*"
    }
  ]
}
```

#### Pod Service Account Policy (IRSA)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SecretsManagerReadOnly",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:sdd-infra/*"
    }
  ]
}
```

---

## Terraform Structure

### File Organization

```
src/terraform/
├── modules/
│   └── iam/
│       ├── main.tf              # IAM roles, policies, instance profiles
│       ├── variables.tf          # Input variables
│       ├── outputs.tf            # Role ARNs, instance profile names
│       └── policies/             # JSON policy files
│           ├── control_plane.json
│           ├── worker_node.json
│           └── pod_service_account.json
```

### Module Inputs (variables.tf)

```hcl
variable "project_name" {
  description = "Project name for naming IAM resources"
  type        = string
  default     = "sdd-infra"
}

variable "environment" {
  description = "Environment (aws, ministack)"
  type        = string
  default     = "aws"
}

variable "aws_account_id" {
  description = "AWS Account ID (for ARNs)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the Kubernetes OIDC provider (set by Spec 003)"
  type        = string
  default     = ""  # Will be provided after control plane bootstrap
}

variable "create_pod_role" {
  description = "Whether to create pod service account role (depends on OIDC provider)"
  type        = bool
  default     = false
}
```

### Module Outputs (outputs.tf)

```hcl
output "control_plane_role_arn" {
  description = "ARN of the control plane IAM role"
  value       = aws_iam_role.control_plane.arn
}

output "control_plane_instance_profile_name" {
  description = "Instance profile name for control plane"
  value       = aws_iam_instance_profile.control_plane.name
}

output "worker_role_arn" {
  description = "ARN of the worker node IAM role"
  value       = aws_iam_role.worker.arn
}

output "worker_instance_profile_name" {
  description = "Instance profile name for worker nodes"
  value       = aws_iam_instance_profile.worker.name
}

output "pod_service_account_role_arn" {
  description = "ARN of the pod service account role (for IRSA)"
  value       = try(aws_iam_role.pod_service_account[0].arn, "")
}
```

---

## Testing Strategy

### Unit Testing

```bash
cd src/terraform/environments/aws
terraform init
terraform plan -target=module.iam
# Verify all roles, policies, and instance profiles are created
```

### Integration Testing

1. **Verify roles exist in AWS:**
   ```bash
   aws iam list-roles --query "Roles[?RoleName=='sdd-infra-control-plane']"
   aws iam list-roles --query "Roles[?RoleName=='sdd-infra-worker']"
   ```

2. **Check policy attachments:**
   ```bash
   aws iam list-role-policies --role-name sdd-infra-control-plane
   aws iam list-role-policies --role-name sdd-infra-worker
   ```

3. **Validate policy content (no overly permissive rules):**
   ```bash
   aws iam get-role-policy --role-name sdd-infra-control-plane --policy-name AllowEC2Describe
   # Verify Resource is not "*" except where necessary
   ```

4. **Ministack validation:**
   - IAM is AWS-specific; ministack may not support it
   - Alternatively, create a simpler "local" mock for testing

---

## Success Criteria

✅ **IAM Roles Created**
- [ ] Control plane role exists with correct trust policy
- [ ] Worker node role exists with correct trust policy
- [ ] Pod service account role exists (once OIDC provider is ready)

✅ **Policies Attached**
- [ ] Control plane policy allows EC2 describe, Route53, Secrets Manager
- [ ] Worker policy allows EC2 describe, Secrets Manager
- [ ] Pod role policy allows read-only Secrets Manager access

✅ **Instance Profiles**
- [ ] Control plane instance profile created and linked to role
- [ ] Worker instance profiles created and linked to role

✅ **Least Privilege**
- [ ] No policies grant `"*"` for Principal or Action (except where necessary for EC2 service)
- [ ] All secrets access is scoped to `sdd-infra/*` namespace
- [ ] No wildcard resource access (e.g., Route53 limited to hosted zones)

✅ **Documentation**
- [ ] Each policy has a comment explaining why each permission is needed
- [ ] Trust policy clearly shows which services/principals can assume the role

---

## Dependencies & Assumptions

### External Dependencies
- AWS account with IAM permissions to create roles and policies
- Terraform 1.0+

### Assumptions
- AWS account ID is known and provided as variable
- OIDC provider ARN will be available after control plane bootstrap (Spec 003)
- All secrets will be tagged with prefix `sdd-infra/` in AWS Secrets Manager

---

## Deliverables

1. **Terraform Module:** `src/terraform/modules/iam/` (complete, tested)
2. **Policy Files:** JSON files for each role's inline policies
3. **Environment Config:** Integration with `environments/aws/` main.tf
4. **Documentation:** This spec + inline comments in `.tf` files
5. **Validation Report:** IAM roles and policies verified in AWS

---

## Notes

- **IRSA Setup:** The pod service account role requires the Kubernetes OIDC provider (created in Spec 003). This spec creates the role but marks it as optional until the OIDC provider is ready.
- **Ministack:** IAM is AWS-specific. For ministack testing, create stub IAM resources or skip IAM entirely (test with full AWS credentials on the node).
- **Policy as Code:** Consider using AWS Policy Simulator or `terraform plan` output to verify policies before deployment.

---

## Next Steps

Once this spec is **complete & tested**:
1. ← **Scaffolding Spec 001:** Networking (completed)
2. → **Scaffolding Spec 003:** EC2 Instances & kubeadm Bootstrap (uses these IAM roles)

---

## Decision Log References

- **D002:** Terraform + kubeadm — IAM roles enable EC2 nodes to communicate with AWS services
- **D004:** Secret Management — AWS Secrets Manager + IRSA requires these IAM roles

---

**Sign-Off:**
- **Author:** Coda
- **Status:** Ready for scaffolding implementation
