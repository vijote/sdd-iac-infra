# Production environment Kubernetes cluster

terraform {
  required_version = ">= 1.0"
}

# Reference networking module (from Spec 001)
module "networking" {
  source = "../../modules/networking"

  environment = "prod"
  vpc_cidr    = "10.1.0.0/16"

  public_subnet_cidr   = "10.1.1.0/24"
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

  # Enable Kubernetes security groups
  enable_control_plane_sg = true
  enable_worker_node_sg   = true
  enable_ingress_sg       = false
}

# Kubernetes cluster module
module "kubernetes" {
  source = "../../modules/kubernetes"

  environment  = "prod"
  cluster_name = "sdd-k8s-prod"

  subnet_ids = module.networking.private_subnet_ids
  security_group_ids = [
    module.networking.control_plane_security_group_id,
    module.networking.worker_node_security_group_id
  ]

  control_plane_instance_type = "t3.medium"
  worker_instance_type        = "t3.small"
  worker_count                = 3
}