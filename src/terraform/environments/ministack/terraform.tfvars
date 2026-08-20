# Ministack Environment Configuration
vpc_cidr           = "172.18.0.0/16"
public_subnet_cidr = "172.18.1.0/24"
private_subnet_cidrs = [
  "172.18.2.0/24",
  "172.18.3.0/24"
]
aws_region         = "local"
availability_zones = []

environment  = "development"
project_name = "sdd-infra"

additional_tags = {
  Environment = "development"
  Owner       = "platform-team"
  CostCenter  = "engineering"
}