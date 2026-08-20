# AWS Environment Configuration
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidrs = [
  "10.0.2.0/24",
  "10.0.3.0/24"
]
aws_region         = "us-west-2"
availability_zones = ["us-west-2a", "us-west-2b"]

environment  = "development"
project_name = "sdd-infra"

additional_tags = {
  Environment = "development"
  Owner       = "platform-team"
  CostCenter  = "engineering"
}