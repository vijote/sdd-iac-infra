# VPC Outputs
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_main_route_table_id" {
  description = "ID of the main route table"
  value       = aws_vpc.main.main_route_table_id
}

# Subnet Outputs
output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = aws_subnet.public.cidr_block
}

output "public_subnet_availability_zone" {
  description = "Availability zone of the public subnet"
  value       = aws_subnet.public.availability_zone
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_availability_zones" {
  description = "List of private subnet availability zones"
  value       = aws_subnet.private[*].availability_zone
}

# Security Group Outputs
output "control_plane_security_group_id" {
  description = "ID of the control plane security group"
  value       = var.enable_control_plane_sg ? aws_security_group.control_plane[0].id : null
}

output "worker_node_security_group_id" {
  description = "ID of the worker node security group"
  value       = var.enable_worker_node_sg ? aws_security_group.worker_node[0].id : null
}

output "ingress_security_group_id" {
  description = "ID of the ingress security group"
  value       = var.enable_ingress_sg ? aws_security_group.ingress[0].id : null
}

output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    control_plane = var.enable_control_plane_sg ? aws_security_group.control_plane[0].id : null
    worker_node   = var.enable_worker_node_sg ? aws_security_group.worker_node[0].id : null
    ingress       = var.enable_ingress_sg ? aws_security_group.ingress[0].id : null
  }
}

# Internet Gateway Outputs
output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = aws_internet_gateway.main.id
}

# Route Table Outputs
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

# Route Table Association Outputs
output "public_route_table_association_id" {
  description = "ID of the public route table association"
  value       = aws_route_table_association.public.id
}

output "private_route_table_association_ids" {
  description = "List of private route table association IDs"
  value       = aws_route_table_association.private[*].id
}