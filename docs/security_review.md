# Security Review Checklist

**Purpose**: Ensure compliance with Constitution Principle VII - Security Defaults, Not Afterthought
**Applies to**: All security group implementations and changes

## Constitution Principle VII Requirements

> "IAM roles are least-privilege. Secrets are never in code; AWS Secrets Manager is mandatory. Inter-node communication is encrypted (Flannel VXLAN). VPC security groups restrict traffic. RBAC is minimal but foundational. Security reviews required for any changes."

---

## Pre-Implementation Checklist

### Planning & Design
- [ ] Business justification documented for each security group
- [ ] Required ports identified and approved
- [ ] Source/destination ranges defined with minimal scope
- [ ] Inter-service communication requirements mapped

### Least-Privilege Verification
- [ ] Security groups only allow explicitly required ports
- [ ] No overly permissive CIDR blocks (0.0.0.0/0) except where justified
- [ ] Source restrictions are as specific as possible
- [ ] Time-bound access rules where applicable

---

## Kubernetes Security Requirements

### Control Plane Security Group
- [ ] Port 6443 (kubelet API) allowed from authorized sources only
- [ ] Ports 2379-2380 (etcd) allowed from control plane nodes only
- [ ] Port 4789 (VXLAN) allowed from all nodes in cluster
- [ ] No unnecessary ports exposed to internet

### Worker Node Security Group
- [ ] Port 4789 (VXLAN) allowed for pod networking
- [ ] Inter-node communication enabled for cluster operations
- [ ] No direct exposure to internet
- [ ] NodePort ranges restricted if used

### Ingress Security Group
- [ ] Port 80 (HTTP) allowed from internet
- [ ] Port 443 (HTTPS) allowed from internet
- [ ] No other ports exposed to internet
- [ ] SSL/TLS enforcement documented

---

## AWS Security Best Practices

### Network Security
- [ ] No hardcoded credentials in security group rules
- [ ] Proper security group naming conventions
- [ ] Descriptions explain business purpose
- [ ] Tags include security classification

### Access Control
- [ ] Security groups reference IAM roles where appropriate
- [ ] Egress rules follow least-privilege principle
- [ ] No unnecessary outbound internet access
- [ ] VPC flow logs enabled for monitoring

---

## Implementation Validation

### Code Review
- [ ] Terraform code reviewed by peer
- [ ] Security group rules match design specifications
- [ ] Variable validation prevents misconfiguration
- [ ] No sensitive data in code

### Testing
- [ ] `terraform plan` reviewed for security implications
- [ ] Network connectivity tested with least-privilege rules
- [ ] Unauthorized traffic attempts blocked (verified)
- [ ] Pod-to-pod communication works correctly

---

## Post-Deployment Verification

### Security Validation
- [ ] All security group rules active as designed
- [ ] Network access logs reviewed for anomalies
- [ ] Security scanning tools pass
- [ ] Documentation updated with actual configuration

### Compliance
- [ ] Security review signed off
- [ ] Decision log updated with security decisions
- [ ] Runbooks include security procedures
- [ ] Monitoring alerts configured for security events

---

## Exceptions & Justifications

Any deviation from least-privilege principle requires:

1. **Business Justification**: Clear business need documented
2. **Risk Assessment**: Security risks identified and accepted
3. **Time Limitation**: Temporary access with expiration date
4. **Approval**: Security team lead sign-off
5. **Monitoring**: Enhanced monitoring for exception period

---

## Review Sign-off

**Reviewer**: _________________________ **Date**: _________

**Security Group Changes Approved**: ☐ Yes ☐ No (with comments)

**Comments/Concerns**:
________________________________________________________________
________________________________________________________________

**Follow-up Actions Required**:
________________________________________________________________
________________________________________________________________

---

## Related Documents

- [Constitution Principle VII](../.specify/memory/constitution.md)
- [VPC Networking Specification](../specs/001-vpc-networking-foundation/spec.md)
- [Security Group Implementation Tasks](../specs/001-vpc-networking-foundation/tasks.md)
- [AWS Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)