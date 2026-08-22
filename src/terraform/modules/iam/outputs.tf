output "terraform_role_arn" {
  description = "ARN of the Terraform execution role"
  value       = aws_iam_role.terraform_role.arn
}

output "terraform_role_name" {
  description = "Name of the Terraform execution role"
  value       = aws_iam_role.terraform_role.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_oidc_provider.github.arn
}

output "oidc_provider_url" {
  description = "URL of the GitHub OIDC provider"
  value       = aws_iam_oidc_provider.github.url
}