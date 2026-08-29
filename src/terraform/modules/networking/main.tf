# VPC Resource
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = local.vpc_tags
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = local.use_availability_zones ? var.availability_zones[0] : null

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-subnet"
      Type = "public"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = local.use_availability_zones && count.index < length(var.availability_zones) ? var.availability_zones[count.index] : null

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-subnet-${count.index + 1}"
      Type = "private"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = local.internet_gateway_tags
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-rt"
      Type = "public"
    }
  )
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  # Only local route (no internet gateway for cost optimization)

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-rt-${count.index + 1}"
      Type = "private"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Control Plane Security Group
resource "aws_security_group" "control_plane" {
  count = var.enable_control_plane_sg ? 1 : 0

  name_prefix = "${var.project_name}-control-plane-"
  description = "Security group for Kubernetes control plane nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-control-plane-sg"
      Type = "control-plane"
    }
  )
}

resource "aws_security_group_rule" "control_plane_ssh" {
  count = var.enable_control_plane_sg ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.control_plane[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow SSH access from external runners"
}

resource "aws_security_group_rule" "control_plane_api_external" {
  count = var.enable_control_plane_sg ? 1 : 0

  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.control_plane[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Kubernetes API server external access for kubectl"
}

# Control Plane Ingress Rules
resource "aws_security_group_rule" "control_plane_kubelet" {
  count = var.enable_control_plane_sg ? 1 : 0

  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.control_plane[0].id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "Kubelet API server"
}

resource "aws_security_group_rule" "control_plane_etcd" {
  count = var.enable_control_plane_sg ? 1 : 0

  type              = "ingress"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  security_group_id = aws_security_group.control_plane[0].id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "etcd server client API"
}

resource "aws_security_group_rule" "control_plane_vxlan" {
  count = var.enable_control_plane_sg ? 1 : 0

  type              = "ingress"
  from_port         = 4789
  to_port           = 4789
  protocol          = "udp"
  security_group_id = aws_security_group.control_plane[0].id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "VXLAN overlay networking"
}

# Control Plane Egress Rule
resource "aws_security_group_rule" "control_plane_egress" {
  count = var.enable_control_plane_sg ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.control_plane[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

# Worker Node Security Group
resource "aws_security_group" "worker_node" {
  count = var.enable_worker_node_sg ? 1 : 0

  name_prefix = "${var.project_name}-worker-node-"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-worker-node-sg"
      Type = "worker-node"
    }
  )
}

# Worker Node Ingress Rules
resource "aws_security_group_rule" "worker_node_vxlan" {
  count = var.enable_worker_node_sg ? 1 : 0

  type              = "ingress"
  from_port         = 4789
  to_port           = 4789
  protocol          = "udp"
  security_group_id = aws_security_group.worker_node[0].id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "VXLAN overlay networking for pod communication"
}

resource "aws_security_group_rule" "worker_node_nodeport" {
  count = var.enable_worker_node_sg ? 1 : 0

  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  security_group_id = aws_security_group.worker_node[0].id
  cidr_blocks       = [aws_vpc.main.cidr_block]
  description       = "NodePort service range"
}

# Worker Node Egress Rule
resource "aws_security_group_rule" "worker_node_egress" {
  count = var.enable_worker_node_sg ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.worker_node[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

# Ingress Security Group
resource "aws_security_group" "ingress" {
  count = var.enable_ingress_sg ? 1 : 0

  name_prefix = "${var.project_name}-ingress-"
  description = "Security group for Kubernetes ingress controllers"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ingress-sg"
      Type = "ingress"
    }
  )
}

# Ingress Ingress Rules
resource "aws_security_group_rule" "ingress_http" {
  count = var.enable_ingress_sg ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.ingress[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP traffic from internet"
}

resource "aws_security_group_rule" "ingress_https" {
  count = var.enable_ingress_sg ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ingress[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS traffic from internet"
}

# Ingress Egress Rule
resource "aws_security_group_rule" "ingress_egress" {
  count = var.enable_ingress_sg ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ingress[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

# Inter-Security Group Communication for Pod-to-Pod Traffic
resource "aws_security_group_rule" "control_plane_to_worker" {
  count = var.enable_control_plane_sg && var.enable_worker_node_sg ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker_node[0].id
  source_security_group_id = aws_security_group.control_plane[0].id
  description              = "Allow all traffic from control plane to worker nodes"
}

resource "aws_security_group_rule" "worker_to_control_plane" {
  count = var.enable_control_plane_sg && var.enable_worker_node_sg ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.control_plane[0].id
  source_security_group_id = aws_security_group.worker_node[0].id
  description              = "Allow all traffic from worker nodes to control plane"
}

resource "aws_security_group_rule" "worker_to_worker" {
  count = var.enable_worker_node_sg ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker_node[0].id
  source_security_group_id = aws_security_group.worker_node[0].id
  description              = "Allow all traffic between worker nodes for pod communication"
}

resource "aws_security_group_rule" "ingress_to_worker" {
  count = var.enable_ingress_sg && var.enable_worker_node_sg ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker_node[0].id
  source_security_group_id = aws_security_group.ingress[0].id
  description              = "Allow traffic from ingress to worker nodes"
}