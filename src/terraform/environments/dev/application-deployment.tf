# Application Deployment Module for Development Environment

module "application_deployment" {
  source = "../../modules/application-deployment"

  # Environment configuration
  environment = "dev"

  # For local development, use kubeconfig
  kubeconfig_path = var.kubeconfig_path

  # Cluster connection details (optional - for CI/CD or remote access)
  cluster_endpoint       = try(module.kubernetes.cluster_endpoint, null)
  cluster_ca_certificate = null
  cluster_token          = null

  # MySQL configuration
  mysql_root_password = var.mysql_root_password
  mysql_database      = var.mysql_database
  mysql_user          = var.mysql_user
  mysql_password      = var.mysql_password
  mysql_storage_size  = var.mysql_storage_size
  mysql_storage_class = var.mysql_storage_class

  # Container images
  frontend_image = var.frontend_image
  backend_image  = var.backend_image
  mysql_image    = var.mysql_image

  # Replicas
  frontend_replicas = var.frontend_replicas
  backend_replicas  = var.backend_replicas
  mysql_replicas    = var.mysql_replicas

  # Resource limits
  frontend_cpu_limit    = var.frontend_cpu_limit
  frontend_memory_limit = var.frontend_memory_limit
  backend_cpu_limit     = var.backend_cpu_limit
  backend_memory_limit  = var.backend_memory_limit
  mysql_cpu_limit       = var.mysql_cpu_limit
  mysql_memory_limit    = var.mysql_memory_limit

  # JWT secret
  jwt_secret = var.jwt_secret
}