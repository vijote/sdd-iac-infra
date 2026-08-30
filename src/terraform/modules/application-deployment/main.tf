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

  yaml_body = templatefile(
    "${path.module}/kubernetes/${each.key}",
    {
      environment = var.environment
      mysql_database = var.mysql_database
      mysql_user     = var.mysql_user
    }
  )

  depends_on = [
    kubernetes_namespace.demo_apps,
    kubernetes_secret.mysql_secrets,
    kubernetes_secret.backend_secrets
  ]
}

# Note: Deployment readiness is handled by Kubernetes automatically