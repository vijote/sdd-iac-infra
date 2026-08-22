output "terraform_role_arn" {
  description = "ARN of the Terraform execution role"
  value       = data.aws_iam_role.terraform_role.arn
}

output "terraform_role_name" {
  description = "Name of the Terraform execution role"
  value       = data.aws_iam_role.terraform_role.name
}

