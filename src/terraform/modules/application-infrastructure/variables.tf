variable "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  type        = string

  validation {
    condition     = can(regex("^https://", var.cluster_endpoint))
    error_message = "Cluster endpoint must be a valid HTTPS URL."
  }
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file for kubeadm cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "Namespace for infrastructure components"
  type        = string
  default     = "application-infrastructure"
}

variable "domain_name" {
  description = "Base domain for SSL certificates"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?)*$", var.domain_name))
    error_message = "Domain name must be a valid domain name."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "storage_classes" {
  description = "Storage class configurations"
  type = map(object({
    type                = string
    iops                = optional(number)
    throughput          = optional(number)
    encrypted           = optional(bool, true)
    reclaim_policy      = optional(string, "Retain")
    allow_expansion     = optional(bool, true)
    volume_binding_mode = optional(string, "WaitForFirstConsumer")
  }))
  default = {}
}

variable "ingress_annotations" {
  description = "Additional annotations for ingress controller"
  type        = map(string)
  default     = {}
}

variable "cert_manager_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
  default     = null

  validation {
    condition     = var.cert_manager_email == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cert_manager_email))
    error_message = "Cert manager email must be a valid email address or null."
  }
}

variable "enable_monitoring" {
  description = "Enable basic monitoring endpoints"
  type        = bool
  default     = false
}

variable "resource_limits" {
  description = "Resource limits for components"
  type = object({
    controller_replicas = optional(number, 2)
  })
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    project    = "sdd-infra"
    managed-by = "terraform"
    component  = "application-infrastructure"
  }
}