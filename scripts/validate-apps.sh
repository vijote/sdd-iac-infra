#!/bin/bash

# Validation script for Application Deployment Infrastructure
# Usage: ./scripts/validate-apps.sh [dev|prod]

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

echo "=== Validating Application Deployment Infrastructure in $ENVIRONMENT ==="

# Navigate to environment directory
cd "src/terraform/environments/$ENVIRONMENT"

# Check Terraform state
echo "Checking Terraform state..."
if ! terraform state list > /dev/null 2>&1; then
    echo "Error: Terraform state not found. Please run deployment first."
    exit 1
fi

# Validate Kubernetes resources
echo "Validating Kubernetes resources..."
kubectl get namespace demo-apps || (echo "Error: demo-apps namespace not found" && exit 1)
kubectl get deployments -n demo-apps || echo "Warning: No deployments found"
kubectl get services -n demo-apps || echo "Warning: No services found"
kubectl get pvc -n demo-apps || echo "Warning: No PVCs found"

# Check application health
echo "Checking application health..."
echo "Frontend service:"
kubectl get service frontend-service -n demo-apps -o wide || echo "Warning: Frontend service not found"

echo "Backend service:"
kubectl get service backend-service -n demo-apps -o wide || echo "Warning: Backend service not found"

echo "MySQL service:"
kubectl get service mysql-service -n demo-apps -o wide || echo "Warning: MySQL service not found"

# Check pod status
echo "Checking pod status..."
kubectl get pods -n demo-apps || echo "Warning: No pods found"

# Show service endpoints
echo "=== Service Endpoints ==="
kubectl get endpoints -n demo-apps || echo "Warning: No endpoints available"

echo "=== Validation completed ==="