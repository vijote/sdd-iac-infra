# GitHub Actions Workflows

This directory contains the GitHub Actions workflows for the SDD Infrastructure project. These workflows implement the CI/CD pipeline using OIDC authentication for secure AWS access.

## 🚀 Workflow Overview

The project uses three main workflows for infrastructure lifecycle management:

1. **Terraform Plan** - Planning and validation
2. **Terraform Apply** - Infrastructure deployment
3. **Destroy Dev Environment** - Cost control and cleanup

---

## 📋 Terraform Plan

**File**: `terraform-plan.yml`  
**Purpose**: Generates and reviews Terraform execution plans for infrastructure changes.

### Triggers
- **Pull Requests**: Automatically runs on PRs to `main` or `develop` branches when Terraform files change
- **Manual Dispatch**: Can be triggered manually for any environment

### Features
- **Multi-Environment Support**: Supports both `dev` and `prod` environments
- **PR Comments**: Posts plan results as pull request comments
- **OIDC Authentication**: Secure AWS access without hardcoded credentials
- **Plan Validation**: Validates configuration before deployment

### Usage

#### Automatic (Pull Request)
1. Create a PR targeting `main` or `develop` branches
2. Make changes to files in `src/terraform/` directory
3. Workflow automatically runs and posts plan as PR comment

#### Manual
1. Navigate to **Actions** tab
2. Select **Terraform Plan** workflow
3. Click **Run workflow**
4. Select target environment (`dev` or `prod`)
5. Click **Run workflow**

### Environment Variables
- `AWS_REGION`: us-east-1
- `AWS_BOOTSTRAP_ROLE`: OIDC role for initial authentication
- `AWS_TERRAFORM_ROLE`: Role for Terraform operations
- `STATE_BUCKET_NAME`: S3 bucket for remote state
- `TF_VAR_kubeconfig_path`: Path to kubectl configuration

---

## 🚀 Terraform Apply

**File**: `terraform-apply.yml`  
**Purpose**: Applies Terraform changes to deploy and update infrastructure.

### Triggers
- **Push to Main**: Automatically runs on pushes to `main` branch
- **Manual Dispatch**: Can be triggered manually for any environment

### Features
- **Automated Deployment**: Auto-deploys to dev on main branch pushes
- **Manual Control**: Manual deployment option for both environments
- **Secret Management**: Secure handling of application secrets
- **Complete Deployment**: Applies all infrastructure changes

### Usage

#### Automatic (Main Branch)
1. Push changes to `main` branch
2. Workflow automatically triggers
3. Infrastructure is deployed to `dev` environment

#### Manual
1. Navigate to **Actions** tab
2. Select **Terraform Apply** workflow
3. Click **Run workflow**
4. Select target environment (`dev` or `prod`)
5. Click **Run workflow**

### Environment Variables
All variables from Terraform Plan plus:
- `TF_VAR_mysql_root_password`: Database root password (from secrets)
- `TF_VAR_mysql_password`: Application database password (from secrets)
- `TF_VAR_jwt_secret`: JWT signing secret (from secrets)

### Security Notes
- Production deployments require manual trigger
- All secrets are stored in GitHub repository secrets
- OIDC authentication ensures no hardcoded credentials

---

## 💥 Destroy Dev Environment

**File**: `destroy-dev-environment.yml`  
**Purpose**: Manually destroys the dev environment AWS infrastructure to eliminate costs when not actively using the project.

### Triggers
- **Manual Only**: Requires explicit manual initiation via GitHub Actions UI

### Features
- **Safety Confirmations**: Multiple layers of confirmation to prevent accidental destruction
- **Environment Restriction**: Only allows destruction of the "dev" environment
- **Resource Inventory**: Generates comprehensive inventory before destruction
- **State Backup**: Creates backup of Terraform state for audit and recovery
- **Comprehensive Logging**: Detailed logs and reports for all activities
- **Long Timeout**: 10-hour timeout for complex destructions

### Usage

1. Navigate to the **Actions** tab in the GitHub repository
2. Select **Destroy Dev Environment** workflow
3. Click **Run workflow**
4. Select `dev` as the environment (only option)
5. Type `destroy` in the confirmation field
6. Click **Run workflow** to start

### Safety Mechanisms

#### 1. Input Validation
- Only "dev" environment is accepted
- Confirmation must exactly match "destroy"

#### 2. Multi-Step Confirmation
- Initial confirmation in workflow trigger
- Resource count display before destruction
- Final warning message

#### 3. Dry-Run Capability
- Always generates destruction plan first
- Shows exactly what will be destroyed
- Plan saved for review

#### 4. State Protection
- S3 state bucket is explicitly excluded
- State files backed up before destruction
- Long-term retention for audit

### Artifacts Generated
- `terraform-state-dev-{run_number}`: State backup and plan files
- `inventory-dev-{timestamp}`: Resource inventory
- `destruction_report.md`: Final destruction report

### Cost Impact
- Destroys all billable resources in dev environment
- Reduces monthly costs to ~$0.50 (S3 state storage only)
- GitHub Actions usage within free tier

---

## 🔧 Configuration

### Required Repository Secrets
```yaml
# Application Secrets
MYSQL_ROOT_PASSWORD: "database-root-password"
MYSQL_PASSWORD: "application-db-password"
JWT_SECRET: "jwt-signing-secret"

# AWS Configuration (Repository Variables)
AWS_BOOTSTRAP_ROLE: "arn:aws:iam::account:role/bootstrap-role"
AWS_TERRAFORM_ROLE: "arn:aws:iam::account:role/terraform-role"
AWS_ACCOUNT_ID: "123456789012"
STATE_BUCKET_NAME: "sdd-terraform-state"
TF_VAR_aws_terraform_role_name: "terraform-execution-role"
```

### OIDC Authentication
All workflows use OpenID Connect (OIDC) authentication:
- No hardcoded AWS credentials
- Temporary credentials generated per workflow run
- Role-based access control
- Automatic credential rotation

### Environment Strategy
- **Development**: Automated deployment on main branch pushes
- **Production**: Manual deployment only with explicit approval
- **Destruction**: Manual only for dev environment (cost control)

---

## 🚨 Troubleshooting

### Common Issues

#### Terraform Plan Issues
1. **"Plan failed" errors**
   - Check Terraform syntax in changed files
   - Verify variable definitions
   - Review PR comment for detailed error

2. **"Permission denied" errors**
   - Check OIDC role configuration
   - Verify IAM role has read permissions
   - Ensure S3 state bucket access

#### Terraform Apply Issues
1. **"Apply failed" errors**
   - Review plan output for resource conflicts
   - Check resource dependencies
   - Verify secret configuration

2. **"State lock" errors**
   - Check for other running Terraform operations
   - Force unlock if necessary (with caution)
   - Contact maintainers if lock is stuck

#### Destroy Issues
1. **"Only 'dev' environment is supported"**
   - Ensure you selected "dev" from the dropdown
   - Check for typos in environment selection

2. **"Confirmation must be exactly 'destroy'"**
   - Type `destroy` (lowercase, no quotes)
   - Ensure no extra spaces or characters

3. **"Permission denied" errors**
   - Check OIDC role configuration
   - Verify IAM role has destruction permissions
   - Ensure S3 state bucket access

### Debugging Steps

1. **Check Workflow Logs**
   - Review step-by-step execution
   - Look for error messages and warnings
   - Check environment variable values

2. **Review Generated Artifacts**
   - Download plan files for analysis
   - Check inventory reports
   - Review destruction reports

3. **Local Validation**
   - Run `terraform plan` locally
   - Check `terraform validate` output
   - Verify configuration files

---

## 📊 Monitoring & Observability

### Workflow Metrics
- All workflows generate comprehensive logs
- Artifacts stored for 30 days
- Performance metrics available in GitHub Actions

### Security Monitoring
- All AWS API calls logged via CloudTrail
- OIDC authentication events tracked
- State access logged and audited

### Cost Monitoring
- Resource usage tracked in workflows
- Destruction reports show cost impact
- Regular cleanup of old artifacts

---

## 🔄 Development Guidelines

When modifying workflows:

1. **Test Changes**: Always test in a non-production environment first
2. **Review Safety**: Ensure safety mechanisms remain intact
3. **Update Documentation**: Keep this README updated
4. **Code Review**: All changes require peer review
5. **Version Control**: Commit workflow changes with descriptive messages
6. **Security First**: Never hardcode credentials or sensitive data

### Best Practices
- Use environment variables for configuration
- Implement proper error handling and retries
- Add comprehensive logging and debugging information
- Test OIDC role assumptions
- Validate all inputs and parameters

---

## 📞 Support

For issues or questions:

1. **Self-Service**
   - Check the workflow logs for detailed error messages
   - Review the generated artifacts and reports
   - Consult this documentation

2. **Create Issue**
   Create an issue in the repository with:
   - Workflow name and run ID
   - Error messages and logs
   - Steps taken to reproduce
   - Expected vs actual behavior
   - Environment details (dev/prod)

3. **Emergency**
   - For production issues, contact maintainers immediately
   - Use destroy workflow for cost control if needed
   - Check #incidents channel for ongoing issues

---

**Last Updated**: 2026-08-29  
**Workflow Count**: 3 active workflows  
**Authentication**: OIDC (no hardcoded credentials)  
**Environments**: dev (automated), prod (manual)