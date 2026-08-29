# Output values for Kubernetes cluster module

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "control_plane_instance_id" {
  description = "ID of the control plane instance"
  value       = aws_instance.control_plane.id
}

output "control_plane_public_ip" {
  description = "Public IP of the control plane instance"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane instance"
  value       = aws_instance.control_plane.private_ip
}

output "worker_instance_ids" {
  description = "IDs of the worker instances"
  value       = aws_instance.workers[*].id
}

output "worker_public_ips" {
  description = "Public IPs of the worker instances"
  value       = aws_instance.workers[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of the worker instances"
  value       = aws_instance.workers[*].private_ip
}

output "all_instance_ids" {
  description = "IDs of all instances (control plane + workers)"
  value       = concat([aws_instance.control_plane.id], aws_instance.workers[*].id)
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${aws_instance.control_plane.public_ip}:6443"
}

output "ssh_private_key" {
  value     = tls_private_key.k8s_key.private_key_pem
  sensitive = true
}