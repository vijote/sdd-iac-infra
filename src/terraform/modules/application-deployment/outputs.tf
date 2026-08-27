output "namespace" {
  description = "Kubernetes namespace for demo applications"
  value       = kubernetes_namespace.demo_apps.metadata[0].name
}

output "frontend_service_url" {
  description = "Frontend service URL"
  value       = "http://frontend-service.${var.namespace}.svc.cluster.local"
}

output "backend_service_url" {
  description = "Backend service URL"
  value       = "http://backend-service.${var.namespace}.svc.cluster.local"
}

output "mysql_service_url" {
  description = "MySQL service URL"
  value       = "mysql-service.${var.namespace}.svc.cluster.local"
}

output "frontend_deployment_status" {
  description = "Frontend deployment status"
  value       = try(kubectl_wait.deployments["frontend"].status, "pending")
}

output "backend_deployment_status" {
  description = "Backend deployment status"
  value       = try(kubectl_wait.deployments["backend"].status, "pending")
}

output "mysql_deployment_status" {
  description = "MySQL deployment status"
  value       = try(kubectl_wait.deployments["mysql"].status, "pending")
}

output "mysql_pvc_name" {
  description = "MySQL PVC name"
  value       = "mysql-pvc"
}

output "ingress_url" {
  description = "Ingress URL for external access"
  value       = "http://demo-apps.local"
}

output "deployment_instructions" {
  description = "Instructions for accessing the deployed applications"
  value = <<-EOT
    Applications deployed successfully!
    
    Access URLs:
    - Frontend: ${output.frontend_service_url.value}
    - Backend API: ${output.backend_service_url.value}
    - MySQL: ${output.mysql_service_url.value}
    
    To access from outside the cluster, configure ingress or use port-forwarding:
    kubectl port-forward -n ${var.namespace} svc/frontend-service 8080:80
    kubectl port-forward -n ${var.namespace} svc/backend-service 8081:80
    
    Check deployment status:
    kubectl get pods -n ${var.namespace}
    kubectl get services -n ${var.namespace}
  EOT
}