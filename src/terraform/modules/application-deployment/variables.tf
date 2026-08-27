variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "Kubernetes namespace for demo applications"
  type        = string
  default     = "demo-apps"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "mysql_storage_size" {
  description = "Storage size for MySQL PVC"
  type        = string
  default     = "20Gi"
}

variable "mysql_storage_class" {
  description = "Storage class for MySQL PVC"
  type        = string
  default     = "gp2"
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

variable "frontend_image" {
  description = "Frontend container image"
  type        = string
  default     = "nginx:alpine"
}

variable "backend_image" {
  description = "Backend container image"
  type        = string
  default     = "node:18-alpine"
}

variable "mysql_image" {
  description = "MySQL container image"
  type        = string
  default     = "mysql:8.0"
}

variable "frontend_replicas" {
  description = "Number of frontend replicas"
  type        = number
  default     = 2
}

variable "backend_replicas" {
  description = "Number of backend replicas"
  type        = number
  default     = 2
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
  default     = "300m"
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