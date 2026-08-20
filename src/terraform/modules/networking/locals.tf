locals {
  # Common tags that will be applied to all resources
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      Owner       = "platform-team"
    },
    var.additional_tags
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
}