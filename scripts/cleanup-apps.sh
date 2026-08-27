#!/bin/bash

# Cleanup script for Application Deployment Infrastructure
# Usage: ./scripts/cleanup-apps.sh [dev|prod]

set -e

# Validate input
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [dev|prod]"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "Error: Environment must be 'dev' or 'prod'"
    exit 1
fi

# Safety check
echo "=== WARNING: This will destroy all Application Deployment Infrastructure ==="
echo "Environment: $ENVIRONMENT"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

echo "=== Cleaning up Application Deployment Infrastructure in $ENVIRONMENT ==="

# Navigate to environment directory
cd "src/terraform/environments/$ENVIRONMENT"

# Destroy infrastructure
echo "Destroying infrastructure..."
terraform destroy -var-file="terraform.tfvars" -auto-approve

echo "=== Cleanup completed successfully ==="