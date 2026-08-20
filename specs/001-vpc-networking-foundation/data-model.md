# Data Model: VPC Networking Foundation

**Date**: 2026-08-20  
**Feature**: VPC Networking Foundation

## Core Entities

### VPC
**Purpose**: Virtual network container for all Kubernetes infrastructure  
**Fields**:
- `cidr_block` (string, required): IP address range (e.g., "10.0.0.0/16")
- `enable_dns_hostnames` (boolean, default: true): Enable DNS resolution for instances
- `enable_dns_support` (boolean, default: true): Enable DNS resolution in VPC
- `tags` (map[string]string, required): Resource tags for management and cost tracking

**Validation Rules**:
- CIDR block must be valid RFC 1918 private address space
- Tags must include required project tags (Environment, Project, Owner)

### Subnet
**Purpose**: Network partitions within VPC for different Kubernetes components  
**Fields**:
- `vpc_id` (string, required): Parent VPC identifier
- `cidr_block` (string, required): IP address range for subnet
- `availability_zone` (string, optional): AWS AZ (not used for ministack)
- `map_public_ip_on_launch` (boolean, required): Auto-assign public IPs
- `type` (enum, required): "public" | "private"
- `tags` (map[string]string, required): Resource tags

**Validation Rules**:
- CIDR block must be within parent VPC CIDR range
- Subnet CIDRs must not overlap
- Public subnets must have map_public_ip_on_launch = true
- Private subnets must have map_public_ip_on_launch = false

### Security Group
**Purpose**: Virtual firewall rules controlling instance traffic  
**Fields**:
- `name` (string, required): Security group identifier
- `description` (string, required): Purpose description
- `vpc_id` (string, required): Parent VPC identifier
- `ingress_rules` (array[IngressRule], required): Inbound traffic rules
- `egress_rules` (array[EgressRule], required): Outbound traffic rules
- `tags` (map[string]string, required): Resource tags

**Validation Rules**:
- Must have at least one ingress rule
- Must have egress rule allowing all outbound traffic
- Security group names must be unique within VPC

### IngressRule
**Purpose**: Inbound traffic rule definition  
**Fields**:
- `from_port` (integer, required): Starting port number
- `to_port` (integer, required): Ending port number
- `protocol` (string, required): "tcp" | "udp" | "icmp" | "-1" (all)
- `cidr_blocks` (array[string], optional): Source CIDR ranges
- `security_groups` (array[string], optional): Source security group IDs

**Validation Rules**:
- from_port must be <= to_port
- Must specify either cidr_blocks or security_groups
- Protocol must be valid IANA protocol

### Route Table
**Purpose**: Network routing rules for subnet traffic direction  
**Fields**:
- `vpc_id` (string, required): Parent VPC identifier
- `routes` (array[Route], required): Route definitions
- `subnet_associations` (array[string], required): Associated subnet IDs
- `tags` (map[string]string, required): Resource tags

**Validation Rules**:
- Must have at least one route (local VPC route is automatic)
- Public route tables must have internet gateway route
- Private route tables should only have local routes

### Route
**Purpose**: Individual route definition  
**Fields**:
- `destination_cidr_block` (string, required): Target IP range
- `gateway_id` (string, optional): Internet gateway or VPN gateway ID
- `nat_gateway_id` (string, optional): NAT gateway ID (not used in this design)
- `vpc_peering_connection_id` (string, optional): VPC peering connection ID

**Validation Rules**:
- Must specify exactly one target gateway type
- Destination CIDR cannot overlap with VPC CIDR (except for local route)

## Entity Relationships

```
VPC (1) -----> (N) Subnet
VPC (1) -----> (N) Security Group
VPC (1) -----> (N) Route Table
Subnet (N) -----> (1) Route Table
Security Group (N) -----> (N) Security Group (referenced in rules)
```

## State Transitions

### VPC Lifecycle
1. **PROVISIONING** → **AVAILABLE** (VPC created successfully)
2. **AVAILABLE** → **MODIFYING** (Configuration changes)
3. **MODIFYING** → **AVAILABLE** (Changes applied)
4. **AVAILABLE** → **TERMINATING** (Deletion initiated)
5. **TERMINATING** → **TERMINATED** (Deletion complete)

### Subnet Lifecycle
1. **PROVISIONING** → **AVAILABLE** (Subnet created)
2. **AVAILABLE** → **MODIFYING** (Route table association changes)
3. **MODIFYING** → **AVAILABLE** (Changes applied)
4. **AVAILABLE** → **TERMINATING** → **TERMINATED**

## Configuration Constraints

### CIDR Allocation
- VPC CIDR: /16 block (10.0.0.0/16 for AWS, 172.18.0.0/16 for ministack)
- Subnet CIDRs: /24 blocks within VPC
- Public subnet: 10.0.1.0/24
- Private subnets: 10.0.2.0/24, 10.0.3.0/24

### Security Group Port Requirements
- Control Plane: 6443 (kubelet), 2379-2380 (etcd), 4789 (VXLAN)
- Worker Nodes: 4789 (VXLAN), all ports from control plane
- Ingress: 80 (HTTP), 443 (HTTPS) from internet (0.0.0.0/0)

### Tag Requirements
All resources must include:
- `Environment`: "development" | "staging" | "production"
- `Project`: "sdd-infra"
- `Owner`: Team or individual responsible
- `ManagedBy`: "terraform"