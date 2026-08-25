# Development environment Kubernetes cluster

terraform {
  required_version = ">= 1.0"
}

# Reference networking module (from Spec 001)
module "networking" {
  source = "../../modules/networking"

  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"

  public_subnet_cidr   = "10.0.1.0/24"
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  # Enable Kubernetes security groups
  enable_control_plane_sg = true
  enable_worker_node_sg   = true
  enable_ingress_sg       = false
}

# Kubernetes cluster module
module "kubernetes" {
  source = "../../modules/kubernetes"

  environment  = "dev"
  cluster_name = "sdd-k8s-dev"

  subnet_ids = [module.networking.public_subnet_id]
  security_group_ids = [
    module.networking.control_plane_security_group_id,
    module.networking.worker_node_security_group_id
  ]

  control_plane_instance_type = "t3.small"
  worker_instance_type        = "t3.micro"
  worker_count                = 2
}