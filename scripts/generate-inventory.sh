#!/bin/bash
# Resource inventory generation script for destroy pipeline

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"
INVENTORY_DIR="${2:-inventory-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)}"
TERRAFORM_DIR="src/terraform/environments/${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Create inventory directory
mkdir -p "$INVENTORY_DIR"
log "Created inventory directory: $INVENTORY_DIR"

# Function to export Terraform state
export_terraform_state() {
    log "Exporting Terraform state..."
    cd "$TERRAFORM_DIR"
    
    # Check if terraform is initialized
    if [ ! -d ".terraform" ]; then
        error "Terraform not initialized. Please run 'terraform init' first."
        exit 1
    fi
    
    # Export state as JSON
    terraform show -json > "../../$INVENTORY_DIR/terraform_state.json"
    log "Terraform state exported to terraform_state.json"
    
    # Export state as raw backup
    terraform state pull > "../../$INVENTORY_DIR/terraform.tfstate.backup"
    log "Terraform state backup created"
}

# Function to generate resource inventory from Terraform
generate_terraform_inventory() {
    log "Generating resource inventory from Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Create inventory from Terraform state
    cat > "../../$INVENTORY_DIR/terraform_resources.json" << EOF
{
  "environment": "$ENVIRONMENT",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "resources": [
$(terraform show -json | jq -r '.values.root_module.resources[]? | {
  type: .type,
  name: .name,
  mode: .mode,
  values: .values
} | @tsv' | IFS=$'\t' read -r type name mode values; do
    echo "    {"
    echo "      \"type\": \"$type\","
    echo "      \"name\": \"$name\","
    echo "      \"mode\": \"$mode\","
    echo "      \"values\": $values"
    echo "    },"
done | sed '$ s/,$//')
  ]
}
EOF
    
    # Generate summary
    local resource_count
    resource_count=$(terraform show -json | jq '.values.root_module.resources | length')
    
    cat > "../../$INVENTORY_DIR/terraform_summary.md" << EOF
# Terraform Resource Inventory - $ENVIRONMENT

**Generated**: $(date)  
**Environment**: $ENVIRONMENT  
**Total Resources**: $resource_count

## Resource Types
$(terraform show -json | jq -r '.values.root_module.resources[]? | .type' | sort | uniq -c | while read count type; do
    echo "- $type: $count"
done)

## Resource List
$(terraform show -json | jq -r '.values.root_module.resources[]? | "- \(.type).\(.name) (\(.mode))"')
EOF
    
    log "Terraform inventory generated"
}

# Function to discover AWS resources
discover_aws_resources() {
    log "Discovering AWS resources..."
    
    # EC2 instances
    log "Discovering EC2 instances..."
    aws ec2 describe-instances \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Reservations[*].Instances[*].{InstanceId:InstanceId,InstanceType:InstanceType,State:State.Name,Tags:Tags}" \
        --output json > "$INVENTORY_DIR/ec2_instances.json" || warning "Failed to discover EC2 instances"
    
    # VPC resources
    log "Discovering VPC resources..."
    aws ec2 describe-vpcs \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock,Tags:Tags}" \
        --output json > "$INVENTORY_DIR/vpcs.json" || warning "Failed to discover VPCs"
    
    # Subnets
    log "Discovering subnets..."
    aws ec2 describe-subnets \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Subnets[*].{SubnetId:SubnetId,CidrBlock:CidrBlock,VpcId:VpcId,Tags:Tags}" \
        --output json > "$INVENTORY_DIR/subnets.json" || warning "Failed to discover subnets"
    
    # Security groups
    log "Discovering security groups..."
    aws ec2 describe-security-groups \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,Description:Description,Tags:Tags}" \
        --output json > "$INVENTORY_DIR/security_groups.json" || warning "Failed to discover security groups"
    
    # Internet gateways
    log "Discovering internet gateways..."
    aws ec2 describe-internet-gateways \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "InternetGateways[*].{InternetGatewayId:InternetGatewayId,Attachments:Attachments,Tags:Tags}" \
        --output json > "$INVENTORY_DIR/internet_gateways.json" || warning "Failed to discover internet gateways"
    
    # EBS volumes
    log "Discovering EBS volumes..."
    aws ec2 describe-volumes \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Volumes[*].{VolumeId:VolumeId,Size:Size,State:State,Tags:Tags}" \
        --output json > "$INVENTORY_DIR/ebs_volumes.json" || warning "Failed to discover EBS volumes"
    
    # Load balancers
    log "Discovering load balancers..."
    aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?contains(to_string(Tags[?Key==\`Environment\`].Value), \`$ENVIRONMENT\`)]" \
        --output json > "$INVENTORY_DIR/load_balancers.json" 2>/dev/null || warning "Failed to discover load balancers"
    
    log "AWS resource discovery completed"
}

# Function to generate combined inventory report
generate_combined_report() {
    log "Generating combined inventory report..."
    
    cat > "$INVENTORY_DIR/inventory_report.md" << EOF
# Resource Inventory Report - $ENVIRONMENT

**Generated**: $(date)  
**Environment**: $ENVIRONMENT  
**Inventory Directory**: $INVENTORY_DIR

## Summary

This report contains a comprehensive inventory of all AWS resources tagged with Environment=$ENVIRONMENT that will be affected by the destruction process.

## Files Generated

- \`terraform_state.json\`: Complete Terraform state in JSON format
- \`terraform.tfstate.backup\`: Raw Terraform state backup
- \`terraform_resources.json\`: Parsed Terraform resources
- \`terraform_summary.md\`: Terraform resource summary
- \`ec2_instances.json\`: EC2 instances discovered via AWS CLI
- \`vpcs.json\`: VPC resources
- \`subnets.json\`: Subnet resources
- \`security_groups.json\`: Security groups
- \`internet_gateways.json\`: Internet gateways
- \`ebs_volumes.json\`: EBS volumes
- \`load_balancers.json\`: Load balancers (if any)

## Resource Counts

### Terraform Resources
$(if [ -f "$INVENTORY_DIR/terraform_summary.md" ]; then
    grep "Total Resources" "$INVENTORY_DIR/terraform_summary.md" | sed 's/## //'
else
    echo "- Unable to determine Terraform resource count"
fi)

### AWS Resources
$(if [ -f "$INVENTORY_DIR/ec2_instances.json" ]; then
    local count=$(jq '[.Reservations[].Instances[]] | length' "$INVENTORY_DIR/ec2_instances.json" 2>/dev/null || echo "0")
    echo "- EC2 Instances: $count"
else
    echo "- EC2 Instances: 0"
fi)

$(if [ -f "$INVENTORY_DIR/vpcs.json" ]; then
    local count=$(jq '.Vpcs | length' "$INVENTORY_DIR/vpcs.json" 2>/dev/null || echo "0")
    echo "- VPCs: $count"
else
    echo "- VPCs: 0"
fi)

$(if [ -f "$INVENTORY_DIR/subnets.json" ]; then
    local count=$(jq '.Subnets | length' "$INVENTORY_DIR/subnets.json" 2>/dev/null || echo "0")
    echo "- Subnets: $count"
else
    echo "- Subnets: 0"
fi)

$(if [ -f "$INVENTORY_DIR/security_groups.json" ]; then
    local count=$(jq '.SecurityGroups | length' "$INVENTORY_DIR/security_groups.json" 2>/dev/null || echo "0")
    echo "- Security Groups: $count"
else
    echo "- Security Groups: 0"
fi)

$(if [ -f "$INVENTORY_DIR/ebs_volumes.json" ]; then
    local count=$(jq '.Volumes | length' "$INVENTORY_DIR/ebs_volumes.json" 2>/dev/null || echo "0")
    echo "- EBS Volumes: $count"
else
    echo "- EBS Volumes: 0"
fi)

## Important Notes

1. **S3 State Bucket**: The S3 bucket containing Terraform state is explicitly excluded from destruction
2. **Resource Verification**: Please review the inventory files to ensure all expected resources are listed
3. **Orphaned Resources**: Check for any resources without the Environment tag that might be orphaned
4. **Dependencies**: Some resources may fail to destroy due to dependencies - these will need manual cleanup

## Next Steps

1. Review the inventory files
2. Confirm all resources are expected to be destroyed
3. Proceed with the destruction process
4. Monitor for any failed destructions
5. Perform manual cleanup for any remaining resources

EOF
    
    log "Combined inventory report generated"
}

# Main execution
main() {
    log "Starting resource inventory generation for environment: $ENVIRONMENT"
    
    # Validate environment
    if [ "$ENVIRONMENT" != "dev" ]; then
        error "Only 'dev' environment is supported for destruction"
        exit 1
    fi
    
    # Check if Terraform directory exists
    if [ ! -d "$TERRAFORM_DIR" ]; then
        error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &>/dev/null; then
        error "AWS CLI not configured or invalid credentials"
        exit 1
    fi
    
    # Generate inventory
    export_terraform_state
    generate_terraform_inventory
    discover_aws_resources
    generate_combined_report
    
    log "Resource inventory generation completed successfully"
    log "Inventory location: $INVENTORY_DIR"
    
    # Print summary
    echo ""
    echo "=== Inventory Summary ==="
    echo "Directory: $INVENTORY_DIR"
    echo "Report: $INVENTORY_DIR/inventory_report.md"
    echo ""
    echo "To review the inventory:"
    echo "  cat $INVENTORY_DIR/inventory_report.md"
    echo ""
}

# Run main function
main "$@"