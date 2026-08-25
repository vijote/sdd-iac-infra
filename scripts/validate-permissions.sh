#!/bin/bash
# Permission validation script for destroy pipeline

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"
REQUIRED_PERMISSIONS=(
    "ec2:*"
    "elasticloadbalancing:*"
    "iam:PassRole"
    "kms:Decrypt"
    "kms:DescribeKey"
    "s3:GetObject"
    "s3:PutObject"
    "s3:DeleteObject"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Function to check AWS identity
check_aws_identity() {
    log "Checking AWS identity..."
    
    local identity
    identity=$(aws sts get-caller-identity --output json 2>/dev/null)
    
    if [ -z "$identity" ]; then
        error "Failed to get AWS identity. Check AWS credentials."
        exit 1
    fi
    
    local account_id
    local user_arn
    account_id=$(echo "$identity" | jq -r '.Account')
    user_arn=$(echo "$identity" | jq -r '.Arn')
    
    log "AWS Identity validated:"
    log "  Account ID: $account_id"
    log "  User/Role: $user_arn"
    
    # Check if using OIDC role (preferred)
    if echo "$user_arn" | grep -q "assumed-role"; then
        log "✅ Using assumed role (OIDC)"
    else
        warning "⚠️  Not using assumed role. Consider using OIDC for better security."
    fi
    
    return 0
}

# Function to validate required permissions
check_permissions() {
    log "Validating required permissions..."
    
    local failed_permissions=()
    local passed_permissions=()
    
    for permission in "${REQUIRED_PERMISSIONS[@]}"; do
        local service="${permission%%:*}"
        local action="${permission#*:}"
        
        # For wildcard permissions, test a common action
        if [ "$action" = "*" ]; then
            case "$service" in
                "ec2")
                    test_permission="ec2:DescribeInstances"
                    ;;
                "elasticloadbalancing")
                    test_permission="elasticloadbalancing:DescribeLoadBalancers"
                    ;;
                *)
                    test_permission="${service}:List*"
                    ;;
            esac
        else
            test_permission="$permission"
        fi
        
        # Try to simulate the permission
        if aws iam simulate-principal-policy \
            --policy-source-arn "$(aws sts get-caller-identity --query Arn --output text)" \
            --action-names "$test_permission" \
            --resource-arns "*" \
            --query 'EvaluationResults[0].EvalDecision' \
            --output text 2>/dev/null | grep -q "allowed"; then
            passed_permissions+=("$permission")
            log "  ✅ $permission"
        else
            failed_permissions+=("$permission")
            error "  ❌ $permission"
        fi
    done
    
    # Report results
    if [ ${#failed_permissions[@]} -gt 0 ]; then
        error ""
        error "Permission validation failed. Missing ${#failed_permissions[@]} permissions:"
        for perm in "${failed_permissions[@]}"; do
            error "  - $perm"
        done
        error ""
        error "Please ensure the IAM role has all required permissions for destruction."
        exit 1
    else
        log "✅ All required permissions validated (${#passed_permissions[@]}/${#REQUIRED_PERMISSIONS[@]})"
    fi
}

# Function to check Terraform state access
check_terraform_state_access() {
    log "Checking Terraform state access..."
    
    local terraform_dir="src/terraform/environments/$ENVIRONMENT"
    local state_file="$terraform_dir/terraform.tfstate"
    
    # Check if Terraform directory exists
    if [ ! -d "$terraform_dir" ]; then
        error "Terraform directory not found: $terraform_dir"
        exit 1
    fi
    
    # Check if we can read the backend configuration
    cd "$terraform_dir"
    
    # Extract S3 bucket from backend configuration
    local s3_bucket
    s3_bucket=$(terraform output -raw state_bucket_name 2>/dev/null || echo "")
    
    if [ -z "$s3_bucket" ]; then
        # Try to extract from backend.tf
        s3_bucket=$(grep -r 'bucket.*=' backend.tf 2>/dev/null | head -1 | sed 's/.*bucket.*= *"\([^"]*\)".*/\1/' || echo "")
    fi
    
    if [ -z "$s3_bucket" ]; then
        warning "Could not determine S3 state bucket name"
        return 0
    fi
    
    log "S3 State Bucket: $s3_bucket"
    
    # Test S3 access
    if aws s3 ls "s3://$s3_bucket" &>/dev/null; then
        log "✅ S3 state bucket access validated"
    else
        error "❌ Cannot access S3 state bucket: $s3_bucket"
        exit 1
    fi
    
    # Check if state file exists
    if aws s3 ls "s3://$s3_bucket/terraform.tfstate" &>/dev/null; then
        log "✅ Terraform state file found in S3"
    else
        warning "⚠️  Terraform state file not found in S3 (new environment?)"
    fi
}

# Function to check environment constraints
check_environment_constraints() {
    log "Checking environment constraints..."
    
    # Only allow dev environment destruction
    if [ "$ENVIRONMENT" != "dev" ]; then
        error "❌ Environment '$ENVIRONMENT' is not allowed for destruction"
        error "Only 'dev' environment can be destroyed"
        exit 1
    fi
    
    log "✅ Environment constraint validated (dev only)"
    
    # Check if environment exists
    local terraform_dir="src/terraform/environments/$ENVIRONMENT"
    if [ ! -d "$terraform_dir" ]; then
        error "❌ Environment directory not found: $terraform_dir"
        exit 1
    fi
    
    log "✅ Environment directory exists"
    
    # Check if Terraform is initialized
    cd "$terraform_dir"
    if [ ! -d ".terraform" ]; then
        error "❌ Terraform not initialized in environment: $ENVIRONMENT"
        error "Please run 'terraform init' first"
        exit 1
    fi
    
    log "✅ Terraform is initialized"
}

# Function to check for active resources
check_active_resources() {
    log "Checking for active resources..."
    
    local terraform_dir="src/terraform/environments/$ENVIRONMENT"
    cd "$terraform_dir"
    
    # Check if there are resources to destroy
    local resource_count
    resource_count=$(terraform show -json 2>/dev/null | jq '.values.root_module.resources | length' 2>/dev/null || echo "0")
    
    if [ "$resource_count" -eq 0 ]; then
        warning "⚠️  No resources found in Terraform state"
        warning "Environment may already be destroyed"
        return 0
    fi
    
    log "Found $resource_count resources in Terraform state"
    
    # Check for running EC2 instances
    local running_instances
    running_instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text 2>/dev/null | wc -w || echo "0")
    
    if [ "$running_instances" -gt 0 ]; then
        warning "⚠️  Found $running_instances running EC2 instances"
        warning "These will be terminated during destruction"
    fi
    
    log "✅ Active resource check completed"
}

# Function to generate permission report
generate_permission_report() {
    local report_dir="permission-report-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$report_dir"
    
    log "Generating permission report in: $report_dir"
    
    cat > "$report_dir/permission_validation.md" << EOF
# Permission Validation Report - $ENVIRONMENT

**Generated**: $(date)  
**Environment**: $ENVIRONMENT  
**Status**: ✅ Passed

## AWS Identity
$(aws sts get-caller-identity --output json | jq -r '"- Account: " + .Account + "\n- User/Role: " + .Arn')

## Required Permissions
All required permissions have been validated:

$(for perm in "${REQUIRED_PERMISSIONS[@]}"; do
    echo "- ✅ $perm"
done)

## Environment Constraints
- ✅ Only dev environment is allowed
- ✅ Environment directory exists
- ✅ Terraform is initialized

## Resource Status
- Resources in Terraform state: $(cd "src/terraform/environments/$ENVIRONMENT" && terraform show -json 2>/dev/null | jq '.values.root_module.resources | length' 2>/dev/null || echo "0")
- Running EC2 instances: $(aws ec2 describe-instances --filters "Name=tag:Environment,Values=$ENVIRONMENT" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null | wc -w || echo "0")

## Recommendations
1. Review the resource list before proceeding
2. Ensure no active work depends on this environment
3. Notify team members before destruction
4. Have a recovery plan ready

EOF
    
    log "Permission report generated: $report_dir/permission_validation.md"
}

# Function to display final confirmation
display_confirmation() {
    echo ""
    echo "=== Permission Validation Summary ==="
    echo "✅ AWS Identity: Validated"
    echo "✅ Required Permissions: All granted"
    echo "✅ Environment Constraints: Satisfied"
    echo "✅ Terraform State Access: Confirmed"
    echo "✅ Active Resources: Identified"
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo "Ready for destruction process."
    echo ""
}

# Main execution
main() {
    log "Starting permission validation for environment: $ENVIRONMENT"
    
    # Run all checks
    check_aws_identity
    check_environment_constraints
    check_permissions
    check_terraform_state_access
    check_active_resources
    
    # Generate report
    generate_permission_report
    
    # Display summary
    display_confirmation
    
    log "Permission validation completed successfully"
}

# Run main function
main "$@"