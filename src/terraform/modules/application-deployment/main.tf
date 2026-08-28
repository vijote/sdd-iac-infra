# Terraform configuration is in versions.tf

# Configure Kubernetes provider
provider "kubernetes" {
  # Use kubeconfig by default, switch to direct cluster config only when all required fields are provided
  config_path = (var.cluster_endpoint != null && var.cluster_ca_certificate != null && var.cluster_token != null) ? null : var.kubeconfig_path

  # Use direct cluster configuration only when all required fields are available
  host                   = (var.cluster_endpoint != null && var.cluster_ca_certificate != null && var.cluster_token != null) ? var.cluster_endpoint : null
  cluster_ca_certificate = (var.cluster_endpoint != null && var.cluster_ca_certificate != null && var.cluster_token != null) ? var.cluster_ca_certificate : null
  token                  = (var.cluster_endpoint != null && var.cluster_ca_certificate != null && var.cluster_token != null) ? var.cluster_token : null
}

# Configure kubectl provider
provider "kubectl" {
  # Use kubeconfig by default, switch to direct cluster config only when all required fields are provided
  config_path = (var.cluster_endpoint != null && var.cluster_ca_certificate != null && var.cluster_token != null) ? null : var.kubeconfig_path

  # Use direct cluster configuration only when all required fields are available
  host                   = (var.cluster_endpoint != null && var.cluster_ca_certificate != null && var.cluster_token != null) ? var.cluster_endpoint : null
  cluster_ca_certificate = (var.cluster_endpoint != null && var.cluster_ca_certificate != null && var.cluster_token != null) ? var.cluster_ca_certificate : null
  token                  = (var.cluster_endpoint != null && var.cluster_ca_certificate != null && var.cluster_token != null) ? var.cluster_token : null
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

# Deploy all Kubernetes manifests from the kubernetes directory (except secrets)
resource "kubectl_manifest" "deployments" {
  for_each = fileset("${path.module}/kubernetes", "**/*.yaml")

  yaml_body = file("${path.module}/kubernetes/${each.key}")

  depends_on = [kubernetes_namespace.demo_apps, kubernetes_secret.mysql_secrets, kubernetes_secret.backend_secrets]
}

# Note: Deployment readiness is handled by Kubernetes automatically