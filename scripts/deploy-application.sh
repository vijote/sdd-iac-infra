#!/bin/bash

# Application Deployment Script
# Usage: ./deploy-application.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
DEPLOYMENT_ORDER=("mysql" "backend" "frontend")
TIMEOUT=300

echo "Deploying applications for ${DEPLOYMENT_ID} to ${ENVIRONMENT}..."

# Function to apply Kubernetes manifests
apply_manifests() {
    local app_name=$1
    local namespace=$2
    local environment=$3
    
    echo "Applying manifests for ${app_name}..."
    
    # Check if manifests directory exists
    local manifest_dir="src/terraform/environments/${environment}/k8s/${app_name}"
    
    if [[ ! -d "$manifest_dir" ]]; then
        echo "WARNING: Manifest directory ${manifest_dir} not found for ${app_name}"
        return 0
    fi
    
    # Apply all YAML files in order
    for manifest in "${manifest_dir}"/*.yaml; do
        if [[ -f "$manifest" ]]; then
            echo "Applying ${manifest}..."
            kubectl apply -f "$manifest" -n ${namespace}
        fi
    done
    
    echo "✓ Manifests applied for ${app_name}"
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local app_name=$1
    local namespace=$2
    local timeout=${3:-300}
    
    echo "Waiting for ${app_name} deployment to be ready..."
    
    # Wait for deployment to complete
    kubectl rollout status deployment/${app_name} \
        -n ${namespace} \
        --timeout=${timeout}s
    
    # Verify all replicas are ready
    local desired_replicas=$(kubectl get deployment ${app_name} \
        -n ${namespace} \
        -o jsonpath='{.spec.replicas}')
    
    local ready_replicas=$(kubectl get deployment ${app_name} \
        -n ${namespace} \
        -o jsonpath='{.status.readyReplicas}' || echo "0")
    
    if [[ "$ready_replicas" != "$desired_replicas" ]]; then
        echo "ERROR: ${app_name} deployment not ready (${ready_replicas}/${desired_replicas})"
        return 1
    fi
    
    echo "✓ ${app_name} is ready with ${ready_replicas}/${desired_replicas} replicas"
    return 0
}

# Function to update deployment annotations
update_deployment_annotations() {
    local app_name=$1
    local namespace=$2
    local deployment_id=$3
    local environment=$4
    
    echo "Updating deployment annotations for ${app_name}..."
    
    # Add deployment metadata
    kubectl annotate deployment ${app_name} \
        -n ${namespace} \
        deployment.kubernetes.io/deployment-id="${deployment_id}" \
        deployment.kubernetes.io/environment="${environment}" \
        deployment.kubernetes.io/timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --overwrite
    
    echo "✓ Annotations updated for ${app_name}"
}

# Function to check deployment dependencies
check_dependencies() {
    local app_name=$1
    local namespace=$2
    
    case $app_name in
        "backend")
            # Check if MySQL is ready
            if ! kubectl get pod -l app=mysql -n ${namespace} | grep -q "1/1"; then
                echo "ERROR: MySQL is not ready for backend deployment"
                return 1
            fi
            ;;
        "frontend")
            # Check if backend is ready
            if ! kubectl get pod -l app=backend -n ${namespace} | grep -q "1/1"; then
                echo "ERROR: Backend is not ready for frontend deployment"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Function to create namespace if it doesn't exist
ensure_namespace() {
    local namespace=$1
    
    if ! kubectl get namespace ${namespace} >/dev/null 2>&1; then
        echo "Creating namespace ${namespace}..."
        kubectl create namespace ${namespace}
        echo "✓ Namespace ${namespace} created"
    else
        echo "✓ Namespace ${namespace} already exists"
    fi
}

# Function to deploy single application
deploy_application() {
    local app_name=$1
    local namespace=$2
    local environment=$3
    local deployment_id=$4
    
    echo ""
    echo "Deploying ${app_name}..."
    echo "----------------------------------------"
    
    # Check dependencies
    if ! check_dependencies "$app_name" "$namespace"; then
        echo "ERROR: Dependencies not met for ${app_name}"
        return 1
    fi
    
    # Apply manifests
    if ! apply_manifests "$app_name" "$namespace" "$environment"; then
        echo "ERROR: Failed to apply manifests for ${app_name}"
        return 1
    fi
    
    # Wait for deployment
    if ! wait_for_deployment "$app_name" "$namespace" "$TIMEOUT"; then
        echo "ERROR: Deployment failed for ${app_name}"
        return 1
    fi
    
    # Update annotations
    update_deployment_annotations "$app_name" "$namespace" "$deployment_id" "$environment"
    
    echo "✓ ${app_name} deployed successfully"
    return 0
}

# Function to get service URLs
get_service_urls() {
    local namespace=$1
    
    echo ""
    echo "Service URLs:"
    echo "------------"
    
    # Get all services with external endpoints
    kubectl get services -n ${namespace} \
        -o jsonpath='{range .items[*]}{.metadata.name}: {.status.loadBalancer.ingress[0].hostname or .status.loadBalancer.ingress[0].ip}{"\n"}{end}' | \
        while read line; do
            if [[ -n "$line" && "$line" != ":" ]]; then
                echo "$line"
            fi
        done
}

# Function to verify deployment order
verify_deployment_order() {
    local apps=("$@")
    local namespace=$1
    shift
    
    echo "Verifying deployment order..."
    
    for app in "${apps[@]}"; do
        if kubectl get deployment ${app} -n ${namespace} >/dev/null 2>&1; then
            local revision=$(kubectl get deployment ${app} \
                -n ${namespace} \
                -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' || echo "1")
            
            echo "✓ ${app} is at revision ${revision}"
        else
            echo "WARNING: ${app} deployment not found"
        fi
    done
}

# Main deployment logic
main() {
    echo "Starting application deployment..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Deployment ID: ${DEPLOYMENT_ID}"
    echo "Namespace: ${NAMESPACE}"
    echo "Deployment Order: ${DEPLOYMENT_ORDER[*]}"
    echo "========================================"
    
    # Ensure namespace exists
    ensure_namespace "$NAMESPACE"
    
    # Deploy applications in order
    local deployment_failed=0
    
    for app in "${DEPLOYMENT_ORDER[@]}"; do
        if ! deploy_application "$app" "$NAMESPACE" "$ENVIRONMENT" "$DEPLOYMENT_ID"; then
            deployment_failed=1
            break
        fi
    done
    
    echo ""
    echo "========================================"
    
    if [[ $deployment_failed -eq 0 ]]; then
        echo "✅ All applications deployed successfully"
        
        # Verify deployment order
        verify_deployment_order "${DEPLOYMENT_ORDER[@]}" "$NAMESPACE"
        
        # Show service URLs
        get_service_urls "$NAMESPACE"
        
        echo ""
        echo "Deployment ${DEPLOYMENT_ID} to ${ENVIRONMENT} completed successfully"
        exit 0
    else
        echo "❌ Deployment failed"
        echo "Deployment ${DEPLOYMENT_ID} to ${ENVIRONMENT} encountered errors"
        exit 1
    fi
}

# Handle script interruption
trap 'echo "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"