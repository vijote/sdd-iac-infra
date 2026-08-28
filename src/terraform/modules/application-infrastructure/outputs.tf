output "namespace" {
  description = "Namespace where infrastructure components are deployed"
  value       = kubernetes_namespace.application_infrastructure.metadata[0].name
}


output "cert_manager_version" {
  description = "Version of cert-manager deployed"
  value       = helm_release.cert_manager.version
}

output "nginx_ingress_version" {
  description = "Version of NGINX Ingress controller deployed"
  value       = helm_release.nginx_ingress.version
}

output "nginx_ingress_service_name" {
  description = "Name of the NGINX Ingress controller service"
  value       = helm_release.nginx_ingress.name
}

output "nginx_ingress_namespace" {
  description = "Namespace where NGINX Ingress controller is deployed"
  value       = helm_release.nginx_ingress.namespace
}

output "nginx_ingress_service" {
  description = "NGINX Ingress controller service details"
  value = {
    name = helm_release.nginx_ingress.name
    namespace = helm_release.nginx_ingress.namespace
    status = helm_release.nginx_ingress.status
  }
}

output "cert_manager_issuers" {
  description = "Available cert-manager cluster issuers"
  value = {
    production = var.cert_manager_email != null ? "letsencrypt-prod" : null
    staging    = var.cert_manager_email != null ? "letsencrypt-staging" : null
  }
  depends_on = [
    kubernetes_manifest.letsencrypt_prod_issuer,
    kubernetes_manifest.letsencrypt_staging_issuer
  ]
}

output "storage_classes" {
  description = "Map of created storage classes"
  value       = {
    for k, v in kubernetes_storage_class.storage_classes : k => v.metadata[0].name
  }
  depends_on = [
    kubernetes_storage_class.storage_classes
  ]
}

output "storage_class_details" {
  description = "Detailed information about storage classes"
  value = {
    for k, v in kubernetes_storage_class.storage_classes : k => {
      name              = v.metadata[0].name
      provisioner       = v.storage_provisioner
      parameters        = v.parameters
      reclaim_policy    = v.reclaim_policy
      allow_expansion   = v.allow_volume_expansion
      volume_binding_mode = v.volume_binding_mode
      is_default        = lookup(v.metadata[0].labels, "storageclass.kubernetes.io/is-default-class", "false") == "true"
    }
  }
  depends_on = [
    kubernetes_storage_class.storage_classes
  ]
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = var.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "domain_name" {
  description = "Base domain for SSL certificates"
  value       = var.domain_name
}

# Integration outputs for application-deployment module
output "application_deployment_config" {
  description = "Configuration for application-deployment module integration"
  value = {
    ingress_class = "nginx"
    cert_manager_issuer = var.cert_manager_email != null ? "letsencrypt-prod" : null
    default_storage_class = "gp3"
    namespace = var.namespace
    domain = var.domain_name
  }
  depends_on = [
    helm_release.nginx_ingress,
    kubernetes_manifest.letsencrypt_prod_issuer
  ]
}

output "provider_config" {
  description = "Provider configuration for downstream modules"
  value = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = var.cluster_ca_certificate
    cluster_name          = var.cluster_name
  }
  sensitive = true
}