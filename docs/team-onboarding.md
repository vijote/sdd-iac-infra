# Team Onboarding Guide

Welcome to the SDD Infrastructure team! This guide will help you get started with our infrastructure setup and deployment processes.

## Quick Start

### Prerequisites

1. **AWS Account**: Request access to the project AWS account
2. **GitHub Access**: Ensure you have repository access with Actions permissions
3. **Development Tools**: Install Terraform, Git, and AWS CLI
4. **Communication**: Join team Slack/Teams channels

### Initial Setup

```bash
# Clone the repository
git clone https://github.com/vijote/sdd-iac-infra.git
cd sdd-iac-infra

# Install Terraform (if not already installed)
# macOS
brew install terraform

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install terraform

# Install AWS CLI
# macOS
brew install awscli

# Ubuntu/Debian
sudo apt-get install awscli

# Configure AWS credentials (for local development)
aws configure
```

## Architecture Overview

### Project Structure

```
sdd-iac-infra/
├── .github/workflows/          # CI/CD pipelines
├── src/terraform/
│   ├── modules/               # Reusable infrastructure components
│   │   ├── iam/              # IAM roles and policies
│   │   ├── state/            # Remote state management
│   │   └── networking/       # VPC and networking (Spec 001)
│   └── environments/         # Environment-specific configs
│       ├── dev/              # Development environment
│       ├── staging/          # Staging environment
│       └── prod/             # Production environment
├── tests/                     # Test suites
├── docs/                      # Documentation
└── specs/                     # Feature specifications
```

### Key Concepts

1. **Infrastructure as Code**: All infrastructure defined in Terraform
2. **OIDC Authentication**: No static AWS credentials in CI/CD
3. **Least Privilege**: Minimal permissions for each environment
4. **State Management**: Remote state with locking
5. **Environment Isolation**: Separate configs for dev/staging/prod

## Development Workflow

### 1. Making Changes

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes to Terraform files
# Edit files in src/terraform/modules/ or environments/

# Test locally (optional)
cd src/terraform/environments/dev
terraform init
terraform plan -var-file="terraform.tfvars"
```

### 2. Submitting Changes

```bash
# Commit and push
git add .
git commit -m "feat: add new infrastructure component"
git push origin feature/your-feature-name

# Create Pull Request
# GitHub will automatically run terraform plan
# Review the plan output in PR comments
```

### 3. Deployment Process

- **Development**: Auto-deploy on merge to main
- **Staging**: Manual deployment with optional approval
- **Production**: Manual deployment with mandatory approval

## Environment Access

### Development Environment

- **Purpose**: Development and testing
- **Access**: All team members
- **Deployment**: Automatic on merge
- **Approvals**: Not required

### Staging Environment

- **Purpose**: Pre-production testing
- **Access**: All team members
- **Deployment**: Manual trigger
- **Approvals**: Optional (configurable)

### Production Environment

- **Purpose**: Production infrastructure
- **Access**: Limited team members
- **Deployment**: Manual trigger
- **Approvals**: Required (multiple approvers)

## Security Practices

### OIDC Authentication

We use OpenID Connect for authentication between GitHub Actions and AWS:

```yaml
# Example workflow configuration
permissions:
  id-token: write    # Required for OIDC
  contents: read    # Required for checkout
```

### Least Privilege

Each environment has specific IAM roles with minimal permissions:

```hcl
# Example IAM policy
resource "aws_iam_role_policy" "terraform_permissions" {
  name = "terraform-permissions"
  role = aws_iam_role.terraform_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ec2:DescribeVpcs", "s3:CreateBucket"]
        Resource = ["arn:aws:s3:::terraform-state-dev-*"]
      }
    ]
  })
}
```

### Security Checklist

Before making changes:

- [ ] Understand the security implications
- [ ] Follow least privilege principle
- [ ] Test in development first
- [ ] Review IAM permissions carefully
- [ ] Document security decisions

## Common Tasks

### Adding New Infrastructure

1. **Create Module**: Add to `src/terraform/modules/`
2. **Update Environments**: Reference module in environment configs
3. **Test**: Run terraform plan/apply in dev
4. **Document**: Update README and comments

### Modifying Existing Infrastructure

1. **Understand Impact**: Check dependencies
2. **Plan Carefully**: Review terraform plan output
3. **Test**: Validate in development
4. **Communicate**: Notify team of changes

### Troubleshooting

1. **Check Logs**: GitHub Actions and AWS CloudTrail
2. **Review State**: Terraform state files
3. **Validate Config**: Terraform validate
4. **Ask for Help**: Team communication channels

## Tools and Commands

### Terraform Commands

```bash
# Initialize working directory
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Plan changes
terraform plan -var-file="terraform.tfvars"

# Apply changes
terraform apply -var-file="terraform.tfvars"

# Destroy infrastructure
terraform destroy -var-file="terraform.tfvars"

# Import existing resources
terraform import aws_s3_bucket.example bucket-name
```

### AWS CLI Commands

```bash
# Check current identity
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# List IAM roles
aws iam list-roles

# Check CloudTrail events
aws cloudtrail lookup-events
```

### GitHub Commands

```bash
# Clone repository
git clone https://github.com/vijote/sdd-iac-infra.git

# Create branch
git checkout -b feature-name

# Commit changes
git add .
git commit -m "description"

# Push changes
git push origin feature-name
```

## Testing

### Running Tests

```bash
# Run all tests
go test ./tests/...

# Run specific test suite
go test ./tests/ci_cd/
go test ./tests/integration/

# Run with verbose output
go test -v ./tests/...

# Run integration tests (requires AWS credentials)
go test -tags=integration ./tests/integration/
```

### Writing Tests

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test complete workflows
3. **Security Tests**: Validate security configurations
4. **Performance Tests**: Check performance characteristics

## Monitoring and Alerting

### CloudWatch Metrics

- **Terraform Operations**: Success/failure rates
- **IAM Role Usage**: Authentication attempts
- **State Operations**: Lock/unlock events
- **Cost Monitoring**: Resource usage costs

### Alerts Setup

```bash
# Create CloudWatch alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "TerraformFailures" \
  --metric-name Failures \
  --namespace "Terraform" \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold
```

## Documentation

### Where to Find Information

1. **README Files**: Project and module documentation
2. **Code Comments**: Inline explanations
3. **Specifications**: Detailed feature specs in `specs/`
4. **Troubleshooting Guide**: Common issues and solutions

### Contributing to Documentation

1. **Keep it Current**: Update docs when making changes
2. **Be Clear**: Use simple, direct language
3. **Include Examples**: Provide code examples
4. **Review**: Have team members review changes

## Getting Help

### Team Communication

- **Slack/Teams**: #sdd-infra channel
- **GitHub Issues**: Report bugs and request features
- **Email**: For urgent issues

### External Resources

- **Terraform Documentation**: https://www.terraform.io/docs
- **AWS Documentation**: https://docs.aws.amazon.com
- **GitHub Actions**: https://docs.github.com/en/actions

### Training Resources

1. **Terraform Tutorials**: Official HashiCorp tutorials
2. **AWS Training**: Free AWS digital training
3. **GitHub Learning**: GitHub Actions tutorials

## Best Practices

### Code Quality

- **Consistent Formatting**: Use `terraform fmt`
- **Validation**: Always run `terraform validate`
- **Testing**: Write tests for new features
- **Documentation**: Document complex logic

### Security

- **Principle of Least Privilege**: Minimal permissions
- **No Secrets in Code**: Use environment variables/secrets
- **Regular Reviews**: Periodic security audits
- **Monitoring**: Track access and changes

### Collaboration

- **Code Reviews**: All changes require review
- **Communication**: Discuss major changes first
- **Documentation**: Keep docs up to date
- **Knowledge Sharing**: Share learnings with team

## Checklist for New Team Members

### Week 1: Setup and Orientation

- [ ] Get AWS account access
- [ ] Set up development tools
- [ ] Clone and explore repository
- [ ] Read project documentation
- [ ] Join team communication channels

### Week 2: Learning and Practice

- [ ] Complete Terraform tutorials
- [ ] Practice with development environment
- [ ] Review existing infrastructure
- [ ] Understand deployment process
- [ ] Ask questions and seek guidance

### Week 3: First Contributions

- [ ] Make small documentation changes
- [ ] Review pull requests
- [ ] Participate in team discussions
- [ ] Understand security practices
- [ ] Learn troubleshooting techniques

### Ongoing: Continuous Improvement

- [ ] Stay updated on best practices
- [ ] Contribute to documentation
- [ ] Mentor new team members
- [ ] Suggest process improvements
- [ ] Share knowledge and experiences

---

## Welcome!

We're excited to have you on the team! Don't hesitate to ask questions and seek help. Infrastructure is a team effort, and we're here to support each other.

**Contact Information**:
- **Team Lead**: [Team Lead Name/Email]
- **Slack Channel**: #sdd-infra
- **Email**: sdd-infra@company.com

---

**Last Updated**: 2025-08-22  
**Version**: 1.0  
**Maintainer**: SDD Infrastructure Team