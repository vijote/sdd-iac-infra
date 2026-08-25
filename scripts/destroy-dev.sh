#!/bin/bash
# Destruction orchestration script for dev environment

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"
CONFIRMATION="${2:-destroy}"
DRY_RUN="${3:-false}"
MAX_RETRIES=3
RETRY_DELAY=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
TERRAFORM_DIR="src/terraform/environments/$ENVIRONMENT"
WORKSPACE_DIR="workspace-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$WORKSPACE_DIR/destroy.log"
PLAN_FILE="$WORKSPACE_DIR/destroy.plan"
STATE_BACKUP="$WORKSPACE_DIR/terraform.tfstate.backup"

# Logging functions
log() {
    local message="$1"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $message" | tee -a "$LOG_FILE"
}

error() {
    local message="$1"
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $message" | tee -a "$LOG_FILE" >&2
}

warning() {
    local message="$1"
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $message" | tee -a "$LOG_FILE"
}

info() {
    local message="$1"
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $message" | tee -a "$LOG_FILE"
}

header() {
    local message="$1"
    echo -e "${MAGENTA}=== $message ===${NC}" | tee -a "$LOG_FILE"
}

# Function to initialize workspace
initialize_workspace() {
    header "Initializing Workspace"
    
    # Create workspace directory
    mkdir -p "$WORKSPACE_DIR"
    log "Created workspace: $WORKSPACE_DIR"
    
    # Initialize log file
    cat > "$LOG_FILE" << EOF
# Dev Environment Destruction Log
# Environment: $ENVIRONMENT
# Started: $(date)
# User: $(whoami)
# Dry Run: $DRY_RUN

EOF
    
    log "Workspace initialized successfully"
}

# Function to validate prerequisites
validate_prerequisites() {
    header "Validating Prerequisites"
    
    # Check confirmation
    if [ "$CONFIRMATION" != "destroy" ]; then
        error "Invalid confirmation: '$CONFIRMATION'"
        error "Please use 'destroy' as confirmation"
        exit 1
    fi
    
    log "✅ Confirmation validated"
    
    # Check environment
    if [ "$ENVIRONMENT" != "dev" ]; then
        error "Invalid environment: '$ENVIRONMENT'"
        error "Only 'dev' environment is supported"
        exit 1
    fi
    
    log "✅ Environment validated"
    
    # Check Terraform directory
    if [ ! -d "$TERRAFORM_DIR" ]; then
        error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    log "✅ Terraform directory found"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        error "AWS credentials not configured"
        exit 1
    fi
    
    log "✅ AWS credentials validated"
}

# Function to backup Terraform state
backup_terraform_state() {
    header "Backing Up Terraform State"
    
    cd "$TERRAFORM_DIR"
    
    # Pull current state
    if terraform state pull > "$STATE_BACKUP"; then
        log "✅ Terraform state backed up to: $STATE_BACKUP"
        
        # Calculate checksum
        local checksum
        checksum=$(sha256sum "$STATE_BACKUP" | cut -d' ' -f1)
        log "State backup checksum: $checksum"
        
        # Save checksum
        echo "$checksum" > "$STATE_BACKUP.sha256"
        log "✅ Checksum saved"
    else
        error "Failed to backup Terraform state"
        exit 1
    fi
}

# Function to initialize Terraform
initialize_terraform() {
    header "Initializing Terraform"
    
    cd "$TERRAFORM_DIR"
    
    # Check if already initialized
    if [ ! -d ".terraform" ]; then
        log "Running terraform init..."
        if terraform init; then
            log "✅ Terraform initialized"
        else
            error "Failed to initialize Terraform"
            exit 1
        fi
    else
        log "✅ Terraform already initialized"
    fi
    
    # Verify workspace
    local workspace
    workspace=$(terraform workspace show 2>/dev/null || echo "default")
    log "Current workspace: $workspace"
    
    # Check for state lock
    if terraform force-unlock -help &>/dev/null; then
        log "✅ Terraform force-unlock available"
    fi
}

# Function to generate destruction plan
generate_destruction_plan() {
    header "Generating Destruction Plan"
    
    cd "$TERRAFORM_DIR"
    
    # Generate plan
    log "Running terraform plan -destroy..."
    if terraform plan -destroy -out="$PLAN_FILE" -detailed-exitcode; then
        log "✅ Destruction plan generated: $PLAN_FILE"
        
        # Show plan summary
        local resource_count
        resource_count=$(terraform show -json "$PLAN_FILE" 2>/dev/null | jq '.planned_values.root_module.resources | length' || echo "0")
        log "Resources to be destroyed: $resource_count"
        
        # Save plan details
        terraform show -json "$PLAN_FILE" > "$WORKSPACE_DIR/destroy_plan.json"
        terraform show "$PLAN_FILE" > "$WORKSPACE_DIR/destroy_plan.txt"
        
        # Generate summary
        cat > "$WORKSPACE_DIR/plan_summary.md" << EOF
# Destruction Plan Summary

**Environment**: $ENVIRONMENT  
**Generated**: $(date)  
**Resources to Destroy**: $resource_count  
**Plan File**: $PLAN_FILE

## Resource Types
$(terraform show -json "$PLAN_FILE" 2>/dev/null | jq -r '.planned_values.root_module.resources[]? | .type' | sort | uniq -c | while read count type; do
    echo "- $type: $count"
done)

## Resource List
$(terraform show -json "$PLAN_FILE" 2>/dev/null | jq -r '.planned_values.root_module.resources[]? | "- \(.type).\(.name) (\(.mode))"')

EOF
        
        log "✅ Plan summary generated"
        
        # Display plan
        echo ""
        echo "=== Destruction Plan ==="
        terraform show "$PLAN_FILE"
        echo ""
        
    else
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then
            log "✅ No changes needed (no resources to destroy)"
            return 0
        else
            error "Failed to generate destruction plan"
            exit 1
        fi
    fi
}

# Function to confirm destruction
confirm_destruction() {
    header "Destruction Confirmation"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN MODE: No actual destruction will be performed"
        return 0
    fi
    
    # Display warning
    echo ""
    warning "⚠️  WARNING: About to destroy the $ENVIRONMENT environment!"
    warning "This action is IRREVERSIBLE!"
    echo ""
    
    # Show resource count
    local resource_count
    resource_count=$(terraform show -json "$PLAN_FILE" 2>/dev/null | jq '.planned_values.root_module.resources | length' || echo "0")
    
    log "Resources that will be destroyed: $resource_count"
    
    # Final confirmation
    echo ""
    read -p "Type 'destroy' to proceed with destruction: " user_confirmation
    
    if [ "$user_confirmation" != "destroy" ]; then
        error "Destruction cancelled by user"
        exit 1
    fi
    
    log "✅ User confirmed destruction"
}

# Function to execute destruction
execute_destruction() {
    header "Executing Destruction"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN: Skipping actual destruction"
        return 0
    fi
    
    cd "$TERRAFORM_DIR"
    
    local attempt=1
    local success=false
    
    while [ $attempt -le $MAX_RETRIES ] && [ "$success" = false ]; do
        log "Destruction attempt $attempt of $MAX_RETRIES"
        
        if terraform apply -input=false -auto-approve "$PLAN_FILE" 2>&1 | tee -a "$LOG_FILE"; then
            log "✅ Destruction completed successfully"
            success=true
        else
            local exit_code=$?
            error "Destruction attempt $attempt failed (exit code: $exit_code)"
            
            if [ $attempt -lt $MAX_RETRIES ]; then
                warning "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
                
                # Check for state lock issues
                if terraform force-unlock -help &>/dev/null; then
                    log "Checking for state locks..."
                    # Note: Actual force-unlock requires lock ID, which we'd get from error
                fi
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    if [ "$success" = false ]; then
        error "Destruction failed after $MAX_RETRIES attempts"
        error "Please check the logs and manually clean up remaining resources"
        exit 1
    fi
    
    # Save final state
    terraform show -json > "$WORKSPACE_DIR/final_state.json"
    terraform state list > "$WORKSPACE_DIR/final_resources.txt"
    
    log "✅ Final state saved"
}

# Function to verify destruction
verify_destruction() {
    header "Verifying Destruction"
    
    # Check Terraform state
    cd "$TERRAFORM_DIR"
    
    local remaining_resources
    remaining_resources=$(terraform state list 2>/dev/null | wc -l || echo "0")
    
    if [ "$remaining_resources" -eq 0 ]; then
        log "✅ No resources remaining in Terraform state"
    else
        warning "⚠️  $remaining_resources resources still in Terraform state"
        terraform state list | while read -r resource; do
            warning "  - $resource"
        done
    fi
    
    # Check AWS resources
    log "Checking for remaining AWS resources..."
    
    # EC2 instances
    local remaining_instances
    remaining_instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text 2>/dev/null | wc -w || echo "0")
    
    if [ "$remaining_instances" -eq 0 ]; then
        log "✅ No EC2 instances remaining"
    else
        warning "⚠️  $remaining_instances EC2 instances still exist"
    fi
    
    # VPC resources
    local remaining_vpcs
    remaining_vpcs=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Vpcs[*].VpcId" \
        --output text 2>/dev/null | wc -w || echo "0")
    
    if [ "$remaining_vpcs" -eq 0 ]; then
        log "✅ No VPCs remaining"
    else
        warning "⚠️  $remaining_vpcs VPCs still exist"
    fi
}

# Function to generate destruction report
generate_destruction_report() {
    header "Generating Destruction Report"
    
    local status="Success"
    if [ "${DRY_RUN}" = "true" ]; then
        status="Dry Run"
    fi
    
    cat > "$WORKSPACE_DIR/destruction_report.md" << EOF
# Dev Environment Destruction Report

**Environment**: $ENVIRONMENT  
**Status**: $status  
**Started**: $(date)  
**Completed**: $(date)  
**User**: $(whoami)  
**Dry Run**: $DRY_RUN  

## Summary

- Workspace: $WORKSPACE_DIR
- Log File: $LOG_FILE
- Plan File: $PLAN_FILE
- State Backup: $STATE_BACKUP

## Resources

$(if [ -f "$WORKSPACE_DIR/plan_summary.md" ]; then
    cat "$WORKSPACE_DIR/plan_summary.md"
else
    echo "No plan summary available"
fi)

## Verification Results

- Remaining Terraform resources: $(cd "$TERRAFORM_DIR" && terraform state list 2>/dev/null | wc -l || echo "0")
- Remaining EC2 instances: $(aws ec2 describe-instances --filters "Name=tag:Environment,Values=$ENVIRONMENT" --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null | wc -w || echo "0")
- Remaining VPCs: $(aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=$ENVIRONMENT" --query "Vpcs[*].VpcId" --output text 2>/dev/null | wc -w || echo "0")

## Files Generated

- destroy.log: Complete destruction log
- destroy.plan: Terraform destruction plan
- terraform.tfstate.backup: State backup
- destroy_plan.json: Plan in JSON format
- final_state.json: Final Terraform state
- destruction_report.md: This report

## Recommendations

1. Review remaining resources (if any)
2. Check AWS console for any orphaned resources
3. Verify costs have decreased as expected
4. Keep the state backup for at least 90 days

## Recovery

If you need to restore the environment:
1. Use the state backup: $STATE_BACKUP
2. Run terraform apply to recreate resources
3. Verify all services are running

EOF
    
    log "✅ Destruction report generated: $WORKSPACE_DIR/destruction_report.md"
}

# Function to cleanup workspace
cleanup_workspace() {
    header "Cleanup"
    
    # Archive workspace
    local archive_name="destroy-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    if tar -czf "$archive_name" -C "$(dirname "$WORKSPACE_DIR")" "$(basename "$WORKSPACE_DIR")"; then
        log "✅ Workspace archived: $archive_name"
        
        # Show archive contents
        log "Archive contents:"
        tar -tzf "$archive_name" | head -20
        if [ $(tar -tzf "$archive_name" | wc -l) -gt 20 ]; then
            log "... and $(($(tar -tzf "$archive_name" | wc -l) - 20)) more files"
        fi
    else
        warning "Failed to archive workspace"
    fi
    
    # Remove workspace directory
    if rm -rf "$WORKSPACE_DIR"; then
        log "✅ Workspace directory cleaned up"
    else
        warning "Failed to remove workspace directory"
    fi
}

# Function to display final status
display_final_status() {
    echo ""
    header "Destruction Complete"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "🔍 DRY RUN COMPLETED - No actual destruction performed"
    else
        log "💥 DESTRUCTION COMPLETED"
    fi
    
    echo ""
    log "Environment: $ENVIRONMENT"
    log "Archive: destroy-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).tar.gz"
    log "Log: Available in archive"
    echo ""
    
    if [ "$DRY_RUN" != "true" ]; then
        warning "Remember to:"
        warning "1. Verify costs have decreased"
        warning "2. Check for any remaining resources"
        warning "3. Keep the archive for 90 days"
    fi
}

# Main execution
main() {
    header "Dev Environment Destruction Started"
    
    # Initialize
    initialize_workspace
    
    # Validate
    validate_prerequisites
    
    # Backup
    backup_terraform_state
    
    # Initialize Terraform
    initialize_terraform
    
    # Generate plan
    generate_destruction_plan
    
    # Confirm
    confirm_destruction
    
    # Execute
    execute_destruction
    
    # Verify
    verify_destruction
    
    # Report
    generate_destruction_report
    
    # Cleanup
    cleanup_workspace
    
    # Display status
    display_final_status
    
    log "Destruction process completed successfully"
}

# Handle script interruption
trap 'error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"