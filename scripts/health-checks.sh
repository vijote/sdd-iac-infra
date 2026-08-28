#!/bin/bash

# Application Health Checks Script
# Usage: ./health-checks.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"

echo "Running comprehensive health checks for ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

# Function to check application health endpoint
check_health_endpoint() {
    local app_name=$1
    local namespace=$2
    local health_path=${3:-"/health"}
    
    echo "Checking health endpoint for ${app_name}..."
    
    # Get service URL
    local service_url=$(kubectl get service ${app_name} \
        -n ${namespace} \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
        kubectl get service ${app_name} \
        -n ${namespace} \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
        echo "")
    
    if [[ -z "$service_url" ]]; then
        echo "WARNING: No external endpoint for ${app_name}"
        return 0
    fi
    
    # Check health endpoint
    local health_url="http://${service_url}${health_path}"
    local response=$(curl -s -w "%{http_code}" "${health_url}" || echo "000")
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        echo "✓ ${app_name} health check passed (${health_url})"
        return 0
    else
        echo "ERROR: ${app_name} health check failed (HTTP ${http_code})"
        return 1
    fi
}

# Function to check pod readiness
check_pod_readiness() {
    local app_name=$1
    local namespace=$2
    
    echo "Checking pod readiness for ${app_name}..."
    
    # Get pod status
    local pod_status=$(kubectl get pods \
        -l app=${app_name} \
        -n ${namespace} \
        -o jsonpath='{range .items[*]}{.status.phase}{" "}{.status.containerStatuses[*].ready}{"\n"}{end}')
    
    while read -r phase ready; do
        if [[ "$phase" != "Running" || "$ready" != "true" ]]; then
            echo "ERROR: Pod not ready - Phase: ${phase}, Ready: ${ready}"
            return 1
        fi
    done <<< "$pod_status"
    
    echo "✓ All ${app_name} pods are ready"
    return 0
}

# Function to check service connectivity
check_service_connectivity() {
    local source_app=$1
    local target_app=$2
    local namespace=$3
    
    echo "Checking connectivity from ${source_app} to ${target_app}..."
    
    # Get source pod
    local source_pod=$(kubectl get pods \
        -l app=${source_app} \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$source_pod" ]]; then
        echo "WARNING: No ${source_app} pod found for connectivity test"
        return 0
    fi
    
    # Test connectivity to target service
    if kubectl exec ${source_pod} -n ${namespace} -- \
        curl -f -s --connect-timeout 5 \
        http://${target_app}.${namespace}.svc.cluster.local/health >/dev/null 2>&1; then
        echo "✓ ${source_app} can connect to ${target_app}"
        return 0
    else
        echo "ERROR: ${source_app} cannot connect to ${target_app}"
        return 1
    fi
}

# Function to check resource constraints
check_resource_constraints() {
    local app_name=$1
    local namespace=$2
    
    echo "Checking resource constraints for ${app_name}..."
    
    # Get deployment resource requests/limits
    local deployment=$(kubectl get deployment ${app_name} -n ${namespace} -o json)
    
    # Check if resources are defined
    local requests=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].resources.requests // empty')
    local limits=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].resources.limits // empty')
    
    if [[ -z "$requests" ]]; then
        echo "WARNING: No resource requests defined for ${app_name}"
    fi
    
    if [[ -z "$limits" ]]; then
        echo "WARNING: No resource limits defined for ${app_name}"
    fi
    
    # Check current usage
    local pod=$(kubectl get pods -l app=${app_name} -n ${namespace} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$pod" ]]; then
        local metrics=$(kubectl top pod ${pod} -n ${namespace} --no-headers 2>/dev/null || echo "")
        if [[ -n "$metrics" ]]; then
            echo "✓ Resource metrics available for ${app_name}: ${metrics}"
        else
            echo "WARNING: No resource metrics available for ${app_name}"
        fi
    fi
    
    return 0
}

# Main health check logic
main() {
    local health_failed=0
    
    echo "Starting comprehensive health checks..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Health checks for each application
    local apps=("mysql" "backend" "frontend")
    
    for app in "${apps[@]}"; do
        echo ""
        echo "Health checks for ${app}..."
        
        # Check pod readiness
        if ! check_pod_readiness "$app" "$NAMESPACE"; then
            health_failed=1
        fi
        
        # Check health endpoint (skip for database)
        if [[ "$app" != "mysql" ]]; then
            if ! check_health_endpoint "$app" "$NAMESPACE"; then
                health_failed=1
            fi
        fi
        
        # Check resource constraints
        if ! check_resource_constraints "$app" "$NAMESPACE"; then
            health_failed=1
        fi
    done
    
    echo ""
    echo "Connectivity checks..."
    
    # Check inter-service connectivity
    if ! check_service_connectivity "frontend" "backend" "$NAMESPACE"; then
        health_failed=1
    fi
    
    if ! check_service_connectivity "backend" "mysql" "$NAMESPACE"; then
        health_failed=1
    fi
    
    echo ""
    echo "----------------------------------------"
    
    if [[ $health_failed -eq 0 ]]; then
        echo "✅ All health checks passed"
        echo "Deployment ${DEPLOYMENT_ID} is healthy"
        exit 0
    else
        echo "❌ Some health checks failed"
        echo "Deployment ${DEPLOYMENT_ID} has issues"
        exit 1
    fi
}

# Run main function
main "$@"