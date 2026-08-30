output "app_config" {
  sensitive = false
  value = {
    frontend_image        = var.frontend_image
    backend_image         = var.backend_image
    mysql_image           = var.mysql_image
    frontend_cpu_limit    = var.frontend_cpu_limit
    frontend_memory_limit = var.frontend_memory_limit
    backend_cpu_limit     = var.backend_cpu_limit
    backend_memory_limit  = var.backend_memory_limit
    mysql_cpu_limit       = var.mysql_cpu_limit
    mysql_memory_limit    = var.mysql_memory_limit
    frontend_replicas     = var.frontend_replicas
    backend_replicas      = var.backend_replicas
    mysql_replicas        = var.mysql_replicas
  }
}