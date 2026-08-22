# Quickstart Validation Guide: VPC Networking Foundation

**Date**: 2026-08-20  
**Purpose**: End-to-end validation scenarios for the VPC networking module

## Prerequisites

### Environment Setup
- Terraform 1.5+ installed
- AWS CLI configured with appropriate credentials
- AWS provider 5.0+ available
- Git repository cloned locally

### Required Permissions
```bash
# AWS IAM permissions needed
ec2:CreateVpc
ec2:CreateSubnet
ec2:CreateInternetGateway
ec2:CreateSecurityGroup
ec2:CreateRouteTable
ec2:ModifyVpcAttribute
ec2:AssociateRouteTable
ec2:AttachInternetGateway
ec2:CreateTags
ec2:DeleteVpc
ec2:DeleteSubnet
ec2:DeleteInternetGateway
ec2:DeleteSecurityGroup
ec2:DeleteRouteTable
ec2:DetachInternetGateway
ec2:DisassociateRouteTable
```

## Validation Scenarios

### Scenario 1: Basic VPC Deployment (AWS)

**Objective**: Validate basic VPC creation with default configuration

**Setup Commands**:
```bash
# Clone repository and navigate to module
git clone https://github.com/your-org/sdd-infra.git
cd sdd-infra

# Create test workspace
terraform -chdir=src/terraform/examples/basic workspace new test-vpc
terraform -chdir=src/terraform/examples/basic init

# Apply with default configuration
terraform -chdir=src/terraform/examples/basic apply -auto-approve \
  -var-file="../../environments/aws/terraform.tfvars" \
  -var="environment=development" \
  -var="project_name=test-vpc"
```

**Expected Outcomes**:
1. VPC created with CIDR 10.0.0.0/16
2. 1 public subnet (10.0.1.0/24) created
3. 2 private subnets (10.0.2.0/24, 10.0.3.0/24) created
4. Internet gateway created and attached to VPC
5. Public subnet route table configured with internet gateway route
6. Private subnet route tables configured with local routes only
7. All resources tagged with Environment=development, Project=test-vpc

**Validation Commands**:
```bash
# Check VPC creation
aws ec2 describe-vpcs --filters Name=tag:Project,Values=test-vpc

# Check subnets
aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id>

# Check internet gateway
aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=<vpc-id>

# Check route tables
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<vpc-id>
```

### Scenario 2: Security Groups Validation

**Objective**: Validate Kubernetes-specific security group rules

**Setup Commands**:
```bash
# Deploy with all security groups enabled
terraform -chdir=src/terraform/examples/basic apply -auto-approve \
  -var="environment=development" \
  -var="project_name=test-sg" \
  -var="enable_control_plane_sg=true" \
  -var="enable_worker_node_sg=true" \
  -var="enable_ingress_sg=true"
```

**Expected Outcomes**:
1. Control plane security group allows:
   - Port 6443 (kubelet) from worker nodes
   - Ports 2379-2380 (etcd) from control plane nodes
   - Port 4789 (VXLAN) from all security groups
2. Worker node security group allows:
   - Port 4789 (VXLAN) from all security groups
   - All traffic from control plane security group
3. Ingress security group allows:
   - Port 80 (HTTP) from 0.0.0.0/0
   - Port 443 (HTTPS) from 0.0.0.0/0

**Validation Commands**:
```bash
# Check security group rules
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<vpc-id>

# Test network connectivity (requires test instances)
# Note: This would require creating test instances, which is out of scope
# for this validation scenario
```

### Scenario 3: Provider-Agnostic Configuration

**Objective**: Validate module works with different provider configurations

**AWS Validation**:
```bash
# Use AWS-specific tfvars
terraform -chdir=src/terraform/examples/basic apply -auto-approve \
  -var-file="../../environments/aws/terraform.tfvars"
```

**Ministack Validation**:
```bash
# Use ministack-specific tfvars
terraform -chdir=src/terraform/examples/basic apply -auto-approve \
  -var-file="../../environments/ministack/terraform.tfvars"
```

**Expected Outcomes**:
1. AWS deployment uses 10.0.0.0/16 CIDR
2. Ministack deployment uses 172.18.0.0/16 CIDR
3. Both deployments create identical resource structures
4. All outputs are correctly formatted for respective provider

### Scenario 4: Custom Configuration Validation

**Objective**: Validate module with custom CIDR and tagging

**Setup Commands**:
```bash
terraform -chdir=src/terraform/examples/basic apply -auto-approve \
  -var="vpc_cidr=192.168.0.0/16" \
  -var="public_subnet_cidr=192.168.1.0/24" \
  -var="private_subnet_cidrs=[\"192.168.2.0/24\", \"192.168.3.0/24\"]" \
  -var="environment=staging" \
  -var="project_name=custom-test" \
  -var="additional_tags={Owner=\"test-user\",CostCenter=\"engineering\"}"
```

**Expected Outcomes**:
1. VPC created with custom CIDR 192.168.0.0/16
2. Subnets created with custom CIDRs within VPC range
3. All resources tagged with custom tags
4. Additional tags merged with required tags

## Cleanup Commands

```bash
# Destroy test resources
terraform -chdir=src/terraform/examples/basic destroy -auto-approve \
  -var="environment=development" \
  -var="project_name=test-vpc"

# Delete test workspace
terraform -chdir=src/terraform/examples/basic workspace delete test-vpc
```

## Performance Validation

### Deployment Time
- **Expected**: VPC deployment completes in under 5 minutes
- **Measurement**: `time terraform apply`

### Resource Validation
- **Expected**: All 12 functional requirements satisfied
- **Measurement**: Manual verification against [spec.md](spec.md)

### Security Validation
- **Expected**: 100% success rate for required traffic patterns
- **Measurement**: Security group rule analysis

## Troubleshooting

### Common Issues
1. **Insufficient Permissions**: Ensure AWS credentials have required IAM permissions
2. **CIDR Conflicts**: Verify CIDR blocks don't overlap with existing VPCs
3. **Resource Limits**: Check AWS service limits for VPCs, subnets, and security groups
4. **Provider Version**: Ensure using AWS provider 5.0+ and Terraform 1.5+

### Debug Commands
```bash
# Check Terraform version
terraform version

# Check provider configuration
terraform -chdir=src/terraform/examples/basic init -upgrade

# Validate configuration
terraform -chdir=src/terraform/examples/basic validate

# Check execution plan
terraform -chdir=src/terraform/examples/basic plan
```

## Success Criteria

A deployment is considered successful when:
1. ✅ All resources are created without errors
2. ✅ VPC and subnets have correct CIDR configurations
3. ✅ Security groups have correct port rules
4. ✅ Route tables are properly configured
5. ✅ All resources are tagged correctly
6. ✅ Module outputs are accessible
7. ✅ Deployment completes within 5 minutes
8. ✅ Cleanup removes all resources successfully