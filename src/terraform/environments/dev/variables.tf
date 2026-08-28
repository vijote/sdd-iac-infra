
# Variables for development environment

variable "kubeconfig_path" {
  description = "Path to kubeconfig file for kubeadm cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
  default     = ""
}

variable "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  type        = string
  default     = ""
}

variable "cluster_token" {
  description = "Kubernetes authentication token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "domain_name" {
  description = "Base domain for SSL certificates"
  type        = string
  default     = "dev.example.com"
}

variable "namespace" {
  description = "Namespace for infrastructure components"
  type        = string
  default     = "application-infrastructure"
}


variable "storage_classes" {
  description = "Storage class configurations"
  type        = map(any)
  default     = {}
}

variable "cert_manager_email" {
  description = "Email for cert-manager Let's Encrypt certificates"
  type        = string
  default     = null
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "mysql_database" {
  description = "MySQL database name"
  type        = string
  default     = "demo_app"
}

variable "mysql_user" {
  description = "MySQL user"
  type        = string
  default     = "demo_user"
}

variable "mysql_password" {
  description = "MySQL user password"
  type        = string
  sensitive   = true
}

variable "mysql_storage_size" {
  description = "Storage size for MySQL PVC"
  type        = string
  default     = "20Gi"
}

variable "mysql_storage_class" {
  description = "Storage class for MySQL PVC"
  type        = string
  default     = "gp3"
}

variable "frontend_image" {
  description = "Frontend container image"
  type        = string
  default     = "nginx:1.24-alpine"
}

variable "backend_image" {
  description = "Backend container image"
  type        = string
  default     = "node:18.17-alpine"
}

variable "mysql_image" {
  description = "MySQL container image"
  type        = string
  default     = "mysql:8.0.33"
}

variable "frontend_replicas" {
  description = "Number of frontend replicas"
  type        = number
  default     = 1
}

variable "backend_replicas" {
  description = "Number of backend replicas"
  type        = number
  default     = 1
}

variable "mysql_replicas" {
  description = "Number of MySQL replicas"
  type        = number
  default     = 1
}

variable "frontend_cpu_limit" {
  description = "Frontend CPU limit"
  type        = string
  default     = "100m"
}

variable "frontend_memory_limit" {
  description = "Frontend memory limit"
  type        = string
  default     = "128Mi"
}

variable "backend_cpu_limit" {
  description = "Backend CPU limit"
  type        = string
  default     = "200m"
}

variable "backend_memory_limit" {
  description = "Backend memory limit"
  type        = string
  default     = "256Mi"
}

variable "mysql_cpu_limit" {
  description = "MySQL CPU limit"
  type        = string
  default     = "250m"
}

variable "mysql_memory_limit" {
  description = "MySQL memory limit"
  type        = string
  default     = "512Mi"
}

variable "jwt_secret" {
  description = "JWT secret for backend authentication"
  type        = string
  sensitive   = true
}