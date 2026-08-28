
# Variables for development environment

variable "kubeconfig_path" {
  description = "Path to kubeconfig file for kubeadm cluster"
  type        = string
  default     = "~/.kube/config"
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