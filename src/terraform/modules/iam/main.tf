# OIDC Provider for GitHub Actions
resource "aws_iam_oidc_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = [
    "sts.amazonaws.com"
  ]
  
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
  
  tags = {
    Name        = "github-oidc-provider"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Base IAM Role Trust Policy Template
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    
    principals {
      type        = "Federated"
      identifiers = [aws_iam_oidc_provider.github.arn]
    }
    
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main", "repo:${var.github_repository}:ref:refs/heads/develop"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Terraform Execution Role
resource "aws_iam_role" "terraform_role" {
  name               = "terraform-${var.environment}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  
  tags = {
    Name        = "terraform-${var.environment}-role"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "terraform-execution"
  }
}

# Session Tagging Policy
resource "aws_iam_role_policy" "session_tagging" {
  name = "session-tagging"
  role = aws_iam_role.terraform_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sts:TagSession"
        ]
        Resource = "*"
      }
    ]
  })
}

# Environment-specific least-privilege policies
resource "aws_iam_role_policy" "terraform_permissions" {
  name = "terraform-permissions"
  role = aws_iam_role.terraform_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeVpcEndpoints",
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:ListPolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucket",
          "s3:ListBucket",
          "s3:PutBucketVersioning",
          "s3:GetBucketVersioning",
          "s3:PutBucketEncryption",
          "s3:GetBucketEncryption",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucketVersions"
        ]
        Resource = [
          "arn:aws:s3:::terraform-state-${var.environment}*",
          "arn:aws:s3:::terraform-state-${var.environment}*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table:terraform-locks-${var.environment}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/terraform-*",
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/terraform-*:*"
        ]
      }
    ]
  })
}

# CloudWatch logging for audit trail
resource "aws_iam_role_policy" "cloudwatch_logging" {
  name = "cloudwatch-logging"
  role = aws_iam_role.terraform_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/terraform/*",
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/terraform/*:*"
        ]
      }
    ]
  })
}