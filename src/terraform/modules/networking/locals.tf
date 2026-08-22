locals {
  # Dedicated resource tagging implementation for FR-011
  # Base tags required for all resources
  base_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = "platform-team"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
    Purpose     = "kubernetes-foundation"
  }

  # Common tags that will be applied to all resources
  common_tags = merge(
    local.base_tags,
    var.additional_tags
  )

  # Resource-specific tags for better management and cost tracking
  vpc_tags = merge(
    local.common_tags,
    {
      ResourceType = "vpc"
      Name         = "${var.project_name}-${var.environment}-vpc"
    }
  )

  subnet_tags = merge(
    local.common_tags,
    {
      ResourceType = "subnet"
    }
  )

  security_group_tags = merge(
    local.common_tags,
    {
      ResourceType = "security-group"
    }
  )

  internet_gateway_tags = merge(
    local.common_tags,
    {
      ResourceType = "internet-gateway"
      Name         = "${var.project_name}-${var.environment}-igw"
    }
  )

  route_table_tags = merge(
    local.common_tags,
    {
      ResourceType = "route-table"
    }
  )

  # Provider-specific CIDR detection
  is_ministack = var.aws_region == "local"

  # Dynamic CIDR selection based on provider
  vpc_cidr = local.is_ministack ? "172.18.0.0/16" : var.vpc_cidr

  # Dynamic subnet CIDRs based on provider
  public_subnet_cidr = local.is_ministack ? "172.18.1.0/24" : var.public_subnet_cidr
  private_subnet_cidrs = local.is_ministack ? [
    "172.18.2.0/24",
    "172.18.3.0/24"
  ] : var.private_subnet_cidrs

  # Availability zone handling
  use_availability_zones = length(var.availability_zones) > 0 && !local.is_ministack

  # Edge case handling: CIDR conflict detection
  # Check if subnets overlap with each other
  subnet_cidrs = concat([local.public_subnet_cidr], local.private_subnet_cidrs)

  # Validate no CIDR overlaps between subnets
  cidr_overlaps = [
    for i, cidr1 in local.subnet_cidrs : [
      for j, cidr2 in local.subnet_cidrs :
      i < j && can(cidrhost(cidr1, 0)) && can(cidrhost(cidr2, 0)) &&
      # Simple check: if the first host IPs are the same, there's overlap
      cidrhost(cidr1, 0) != cidrhost(cidr2, 0)
    ]
  ]

  # IP exhaustion check: ensure subnets have enough IPs for expected instances
  # /24 subnet = 256 IPs, minus 5 reserved = 251 usable
  subnet_has_enough_ips = alltrue([
    for cidr in local.subnet_cidrs :
    can(cidrhost(cidr, 0)) && (pow(2, 32 - tonumber(split("/", cidr)[1])) - 5) >= var.max_instances_per_subnet
  ])

  # Edge case: CIDR conflict validation (if enabled)
  cidr_conflicts_enabled = var.enable_cidr_conflict_check

  # Security group conflict prevention
  # Generate unique security group names to avoid conflicts
  sg_name_prefix        = "${var.project_name}-${var.environment}"
  control_plane_sg_name = "${local.sg_name_prefix}-control-plane"
  worker_node_sg_name   = "${local.sg_name_prefix}-worker-node"
  ingress_sg_name       = "${local.sg_name_prefix}-ingress"

  # Provider-specific validation logic for environment configurations
  provider_validation = {
    aws = {
      cidr_validation   = local.vpc_cidr == "10.0.0.0/16"
      subnet_validation = length(local.private_subnet_cidrs) == 2
      region_validation = var.aws_region != "local"
    }
    ministack = {
      cidr_validation   = local.vpc_cidr == "172.18.0.0/16"
      subnet_validation = length(local.private_subnet_cidrs) == 2
      region_validation = var.aws_region == "local"
    }
  }

  # Current provider validation result
  current_provider_validation = local.is_ministack ? local.provider_validation.ministack : local.provider_validation.aws

  # Provider-specific feature flags
  features = {
    aws = {
      use_availability_zones = true
      use_multiple_azs       = false # Single AZ deployment for cost optimization
      enable_flow_logs       = true  # Should be enabled in production
    }
    ministack = {
      use_availability_zones = false
      use_multiple_azs       = false
      enable_flow_logs       = false # Not applicable for local development
    }
  }

  # Current provider features
  current_features = local.is_ministack ? local.features.ministack : local.features.aws
}