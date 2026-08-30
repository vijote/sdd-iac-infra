# Development environment Kubernetes cluster

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  # CI/CD environment - explicitly disable config_path to prevent kubeconfig lookup
  config_path = "~/.kube/config"
  insecure = true

  # Use direct cluster configuration or environment variables
  host                   = var.cluster_endpoint != "" ? var.cluster_endpoint : null
  cluster_ca_certificate = var.cluster_ca_certificate != "" ? var.cluster_ca_certificate : null
  token                  = var.cluster_token != "" ? var.cluster_token : null
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    # CI/CD environment - explicitly disable config_path to prevent kubeconfig lookup
    config_path = "~/.kube/config"
    insecure = true

    # Use direct cluster configuration or environment variables
    host                   = var.cluster_endpoint != "" ? var.cluster_endpoint : null
    cluster_ca_certificate = var.cluster_ca_certificate != "" ? var.cluster_ca_certificate : null
    token                  = var.cluster_token != "" ? var.cluster_token : null
  }
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

  control_plane_instance_type = "t2.medium"
  worker_instance_type        = "t2.micro"
  worker_count                = 2
}

# Application infrastructure module
module "application_infrastructure" {
  source = "../../modules/application-infrastructure"

  # Pass outputs from kubernetes module
  cluster_endpoint       = module.kubernetes.cluster_endpoint
  cluster_ca_certificate = "" # Will be extracted from kubeconfig
  cluster_name           = module.kubernetes.cluster_name

  # Other required variables
  domain_name     = var.domain_name
  kubeconfig_path = var.kubeconfig_path
  namespace       = var.namespace
  aws_region      = var.aws_region

  # Storage classes configuration
  storage_classes = var.storage_classes

  # Cert-manager configuration
  cert_manager_email = var.cert_manager_email

  # Providers
  providers = {
    kubernetes = kubernetes
    helm       = helm
  }
}

output "ec2_ssh_private_key" {
  value     = module.kubernetes.ssh_private_key
  sensitive = true
}