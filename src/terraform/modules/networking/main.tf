# VPC Resource
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
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
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
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