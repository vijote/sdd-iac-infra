# Terraform configuration is in versions.tf

# Configure Kubernetes provider
provider "kubernetes" {
  config_path = "~/.kube/config"
  insecure = true

  host                   = var.cluster_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  token                  = var.cluster_token
}

# Configure kubectl provider
provider "kubectl" {
  config_path = "~/.kube/config"
  insecure    = true
  
  host                   = var.cluster_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  token                  = var.cluster_token
}

# Create namespace for demo applications
resource "kubernetes_namespace" "demo_apps" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# Create MySQL secrets with proper base64 encoding
resource "kubernetes_secret" "mysql_secrets" {
  metadata {
    name      = "mysql-secrets"
    namespace = var.namespace
    labels = {
      app         = "mysql"
      tier        = "database"
      environment = var.environment
    }
  }

  type = "Opaque"

  data = {
    root-password = base64encode(var.mysql_root_password)
    user-password = base64encode(var.mysql_password)
  }

  depends_on = [kubernetes_namespace.demo_apps]
}

# Create backend secrets
resource "kubernetes_secret" "backend_secrets" {
  metadata {
    name      = "backend-secrets"
    namespace = var.namespace
    labels = {
      app         = "backend"
      tier        = "api"
      environment = var.environment
    }
  }

  type = "Opaque"

  data = {
    database-password = base64encode(var.mysql_password)
    jwt-secret        = base64encode(var.jwt_secret)
  }

  depends_on = [kubernetes_namespace.demo_apps]
}

# Deploy all Kubernetes manifests interpreting Terraform template variables
resource "kubectl_manifest" "deployments" {
  for_each = fileset("${path.module}/kubernetes", "**/*.yaml")
  # Evita que el proveedor se quede bloqueado esperando a que los Pods estén 100% listos
  wait = false

  yaml_body = templatefile(
    "${path.module}/kubernetes/${each.key}",
    {
      environment = var.environment
      mysql_database = var.mysql_database
      mysql_user     = var.mysql_user
      mysql_storage_class = var.mysql_storage_class
      frontend_replicas = var.frontend_replicas
      mysql_replicas = var.mysql_replicas
      mysql_image = var.mysql_image
      mysql_storage_size = var.mysql_storage_size
      backend_replicas = var.backend_replicas
      frontend_image = var.frontend_image
      mysql_cpu_limit = var.mysql_cpu_limit
      backend_image = var.backend_image
      frontend_cpu_limit = var.frontend_cpu_limit
      mysql_memory_limit = var.mysql_memory_limit
      backend_cpu_limit = var.backend_cpu_limit
      frontend_memory_limit = var.frontend_memory_limit
      backend_memory_limit = var.backend_memory_limit
    }
  )

  depends_on = [
    kubernetes_namespace.demo_apps,
    kubernetes_secret.mysql_secrets,
    kubernetes_secret.backend_secrets
  ]
}

# Note: Deployment readiness is handled by Kubernetes automatically