# GitHub Actions Workflows

This directory contains the GitHub Actions workflows for the SDD Infrastructure project.

## Workflows

### Destroy Dev Environment

**File**: `destroy-dev-environment.yml`  
**Purpose**: Manually destroys the dev environment AWS infrastructure to eliminate costs when not actively using the project.

#### Features

- **Manual Trigger Only**: Requires explicit manual initiation via GitHub Actions UI
- **Safety Confirmations**: Multiple layers of confirmation to prevent accidental destruction
- **Environment Restriction**: Only allows destruction of the "dev" environment
- **Resource Inventory**: Generates comprehensive inventory before destruction
- **State Backup**: Creates backup of Terraform state for audit and recovery
- **Comprehensive Logging**: Detailed logs and reports for all activities

#### Usage

1. Navigate to the **Actions** tab in the GitHub repository
2. Select **Destroy Dev Environment** workflow
3. Click **Run workflow**
4. Select `dev` as the environment
5. Type `destroy` in the confirmation field
6. Click **Run workflow** to start

#### Safety Mechanisms

1. **Input Validation**:
   - Only "dev" environment is accepted
   - Confirmation must exactly match "destroy"

2. **Multi-Step Confirmation**:
   - Initial confirmation in workflow trigger
   - Resource count display before destruction
   - Final warning message

3. **Dry-Run Capability**:
   - Always generates destruction plan first
   - Shows exactly what will be destroyed
   - Plan saved for review

4. **State Protection**:
   - S3 state bucket is explicitly excluded
   - State files backed up before destruction
   - 365-day retention for audit

#### Artifacts Generated

- `terraform-state-dev-{run_number}`: State backup and plan files
- `inventory-dev-{timestamp}`: Resource inventory
- `destruction_report.md`: Final destruction report

#### Troubleshooting

Common issues and solutions:

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

4. **"State lock" errors**
   - Check for other running Terraform operations
   - Contact maintainers if lock is stuck

#### Security Considerations

- Uses OIDC authentication (no hardcoded credentials)
- Minimum required permissions only
- All operations are logged and auditable
- State files retained for 90 days minimum

#### Cost Impact

- Destroys all billable resources in dev environment
- Reduces monthly costs to ~$0.50 (S3 state storage only)
- GitHub Actions usage within free tier

## Development Guidelines

When modifying workflows:

1. **Test Changes**: Always test in a non-production environment first
2. **Review Safety**: Ensure safety mechanisms remain intact
3. **Update Documentation**: Keep this README updated
4. **Code Review**: All changes require peer review
5. **Version Control**: Commit workflow changes with descriptive messages

## Support

For issues or questions:
1. Check the workflow logs for detailed error messages
2. Review the generated artifacts and reports
3. Create an issue in the repository with:
   - Workflow run ID
   - Error messages
   - Steps taken
   - Expected vs actual behavior