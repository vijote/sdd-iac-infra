#!/bin/bash

# Deployment Validation Script
# Usage: ./validate-deployment.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
TIMEOUT=300
INTERVAL=10

echo "Validating deployment ${DEPLOYMENT_ID} to ${ENVIRONMENT}..."

# Function to check pod health
check_pod_health() {
    local app_name=$1
    local namespace=$2
    
    echo "Checking health for ${app_name}..."
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod \
        -l app=${app_name} \
        -n ${namespace} \
        --timeout=${TIMEOUT}s
    
    # Check pod status
    local pod_status=$(kubectl get pods \
        -l app=${app_name} \
        -n ${namespace} \
        -o jsonpath='{.items[*].status.phase}')
    
    if [[ "$pod_status" != "Running" ]]; then
        echo "ERROR: Pod ${app_name} is not running. Status: ${pod_status}"
        return 1
    fi
    
    # Check if pod is ready
    local ready_count=$(kubectl get pods \
        -l app=${app_name} \
        -n ${namespace} \
        -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | \
        tr ' ' '\n' | grep -c true || echo "0")
    
    local total_count=$(kubectl get pods \
        -l app=${app_name} \
        -n ${namespace} \
        --no-headers | wc -l)
    
    if [[ "$ready_count" != "$total_count" ]]; then
        echo "ERROR: Not all pods for ${app_name} are ready (${ready_count}/${total_count})"
        return 1
    fi
    
    echo "✓ ${app_name} is healthy"
    return 0
}

# Function to check service health
check_service_health() {
    local app_name=$1
    local namespace=$2
    
    echo "Checking service health for ${app_name}..."
    
    # Check if service exists
    if ! kubectl get service ${app_name} -n ${namespace} >/dev/null 2>&1; then
        echo "ERROR: Service ${app_name} not found"
        return 1
    fi
    
    # Get service URL
    local service_url=$(kubectl get service ${app_name} \
        -n ${namespace} \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
        kubectl get service ${app_name} \
        -n ${namespace} \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
        echo "")
    
    if [[ -z "$service_url" ]]; then
        echo "WARNING: Service ${app_name} has no external endpoint"
        return 0
    fi
    
    # Health check endpoint
    local health_url="http://${service_url}/health"
    
    # Wait and check health endpoint
    local elapsed=0
    while [[ $elapsed -lt $TIMEOUT ]]; do
        if curl -f -s "${health_url}" >/dev/null 2>&1; then
            echo "✓ Service ${app_name} is healthy at ${health_url}"
            return 0
        fi
        
        echo "Waiting for ${app_name} health check... (${elapsed}s elapsed)"
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
    done
    
    echo "ERROR: Service ${app_name} health check failed after ${TIMEOUT}s"
    return 1
}

# Function to check database connectivity
check_database_connectivity() {
    local namespace=$1
    
    echo "Checking database connectivity..."
    
    # Check MySQL pod
    if ! kubectl get pod -l app=mysql -n ${namespace} >/dev/null 2>&1; then
        echo "WARNING: MySQL pod not found in namespace ${namespace}"
        return 0
    fi
    
    # Execute database connectivity test
    local mysql_pod=$(kubectl get pod \
        -l app=mysql \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}')
    
    if kubectl exec ${mysql_pod} -n ${namespace} -- \
        mysqladmin ping -h localhost --silent; then
        echo "✓ Database connectivity is healthy"
        return 0
    else
        echo "ERROR: Database connectivity failed"
        return 1
    fi
}

# Function to check resource utilization
check_resource_utilization() {
    local namespace=$1
    
    echo "Checking resource utilization..."
    
    # Get resource usage for all pods
    local resource_usage=$(kubectl top pods \
        -n ${namespace} \
        --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$resource_usage" ]]; then
        echo "WARNING: Could not retrieve resource usage"
        return 0
    fi
    
    # Check for high CPU usage (>80%)
    local high_cpu=$(echo "$resource_usage" | \
        awk '{cpu=substr($2,1,length($2)-1); if(cpu+0 > 80) print $1}')
    
    if [[ -n "$high_cpu" ]]; then
        echo "WARNING: High CPU usage detected: $high_cpu"
    fi
    
    # Check for high memory usage (>80%)
    local high_memory=$(echo "$resource_usage" | \
        awk '{mem=substr($3,1,length($3)-2); if(mem+0 > 80) print $1}')
    
    if [[ -n "$high_memory" ]]; then
        echo "WARNING: High memory usage detected: $high_memory"
    fi
    
    echo "✓ Resource utilization check completed"
    return 0
}

# Main validation logic
main() {
    local validation_failed=0
    
    echo "Starting deployment validation for ${DEPLOYMENT_ID}..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Validate each application
    local apps=("mysql" "backend" "frontend")
    
    for app in "${apps[@]}"; do
        echo ""
        echo "Validating ${app}..."
        
        if ! check_pod_health "$app" "$NAMESPACE"; then
            validation_failed=1
        fi
        
        if ! check_service_health "$app" "$NAMESPACE"; then
            validation_failed=1
        fi
    done
    
    echo ""
    echo "Cross-cutting validations..."
    
    # Check database connectivity
    if ! check_database_connectivity "$NAMESPACE"; then
        validation_failed=1
    fi
    
    # Check resource utilization
    if ! check_resource_utilization "$NAMESPACE"; then
        validation_failed=1
    fi
    
    echo ""
    echo "----------------------------------------"
    if [[ $validation_failed -eq 0 ]]; then
        echo "✅ Deployment validation PASSED"
        echo "Deployment ${DEPLOYMENT_ID} to ${ENVIRONMENT} is healthy"
        
        # Output service URLs
        echo ""
        echo "Service URLs:"
        kubectl get service -n ${NAMESPACE} \
            -o jsonpath='{range .items[*]}{.metadata.name}: {.status.loadBalancer.ingress[0].hostname or .status.loadBalancer.ingress[0].ip}{"\n"}{end}' | \
            grep -v "^:" || echo "No external services found"
        
        exit 0
    else
        echo "❌ Deployment validation FAILED"
        echo "Deployment ${DEPLOYMENT_ID} to ${ENVIRONMENT} has issues"
        exit 1
    fi
}

# Run main function
main "$@"