#!/bin/bash

# Deployment script for Application Deployment Infrastructure
# Usage: ./scripts/deploy-apps.sh [dev|prod]

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

echo "=== Deploying Application Deployment Infrastructure to $ENVIRONMENT ==="

# Navigate to environment directory
cd "src/terraform/environments/$ENVIRONMENT"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan the deployment
echo "Planning deployment..."
terraform plan -var-file="terraform.tfvars" -out="tfplan"

# Apply the deployment
echo "Applying deployment..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

echo "=== Deployment completed successfully ==="

# Show outputs
echo "=== Deployment Outputs ==="
terraform output