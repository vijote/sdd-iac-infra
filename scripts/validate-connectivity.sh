#!/bin/bash

# Inter-Service Connectivity Validation Script
# Usage: ./validate-connectivity.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
TIMEOUT=10

echo "Validating inter-service connectivity for ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

# Function to test service connectivity
test_service_connectivity() {
    local source_pod=$1
    local target_service=$2
    local namespace=$3
    local port=${4:-80}
    
    echo "Testing connectivity from ${source_pod} to ${target_service}..."
    
    # Use nslookup to check DNS resolution
    if kubectl exec ${source_pod} -n ${namespace} -- \
        nslookup ${target_service}.${namespace}.svc.cluster.local >/dev/null 2>&1; then
        echo "✓ DNS resolution successful for ${target_service}"
    else
        echo "ERROR: DNS resolution failed for ${target_service}"
        return 1
    fi
    
    # Use nc (netcat) to test TCP connectivity
    if kubectl exec ${source_pod} -n ${namespace} -- \
        timeout ${TIMEOUT} nc -z ${target_service}.${namespace}.svc.cluster.local ${port}; then
        echo "✓ TCP connection successful to ${target_service}:${port}"
        return 0
    else
        echo "ERROR: TCP connection failed to ${target_service}:${port}"
        return 1
    fi
}

# Function to test HTTP connectivity
test_http_connectivity() {
    local source_pod=$1
    local target_url=$2
    local namespace=$3
    
    echo "Testing HTTP connectivity to ${target_url}..."
    
    # Use curl to test HTTP endpoint
    local response=$(kubectl exec ${source_pod} -n ${namespace} -- \
        curl -s -w "%{http_code}" --connect-timeout ${TIMEOUT} "${target_url}" || echo "000")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" =~ ^[2-3][0-9][0-9]$ ]]; then
        echo "✓ HTTP request successful to ${target_url} (HTTP ${http_code})"
        return 0
    else
        echo "ERROR: HTTP request failed to ${target_url} (HTTP ${http_code})"
        return 1
    fi
}

# Function to test database connectivity
test_database_connectivity() {
    local source_pod=$1
    local db_host=$2
    local db_port=${3:-3306}
    local namespace=$4
    
    echo "Testing database connectivity to ${db_host}:${db_port}..."
    
    # Test TCP connection to database
    if kubectl exec ${source_pod} -n ${namespace} -- \
        timeout ${TIMEOUT} nc -z ${db_host} ${db_port}; then
        echo "✓ Database connection successful to ${db_host}:${db_port}"
        return 0
    else
        echo "ERROR: Database connection failed to ${db_host}:${db_port}"
        return 1
    fi
}

# Function to get pod for application
get_app_pod() {
    local app_name=$1
    local namespace=$2
    
    kubectl get pods \
        -l app=${app_name} \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

# Function to validate service discovery
validate_service_discovery() {
    local namespace=$1
    
    echo "Validating service discovery..."
    
    # List all services in namespace
    local services=$(kubectl get services -n ${namespace} -o jsonpath='{.items[*].metadata.name}')
    
    for service in $services; do
        # Check if service has endpoints
        local endpoints=$(kubectl get endpoints ${service} -n ${namespace} -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
        
        if [[ -n "$endpoints" ]]; then
            echo "✓ Service ${service} has ${#endpoints[@]} endpoint(s)"
        else
            echo "WARNING: Service ${service} has no endpoints"
        fi
    done
}

# Function to test network policies
test_network_policies() {
    local namespace=$1
    
    echo "Testing network policies..."
    
    # Check if network policies exist
    local policies=$(kubectl get networkpolicies -n ${namespace} -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$policies" ]]; then
        echo "✓ Network policies found: ${policies}"
        
        # Test that allowed traffic works
        local frontend_pod=$(get_app_pod "frontend" "$namespace")
        local backend_pod=$(get_app_pod "backend" "$namespace")
        
        if [[ -n "$frontend_pod" && -n "$backend_pod" ]]; then
            if test_service_connectivity "$frontend_pod" "backend" "$namespace" "3000"; then
                echo "✓ Network policies allow frontend → backend traffic"
            else
                echo "WARNING: Network policies may be blocking frontend → backend traffic"
            fi
        fi
    else
        echo "INFO: No network policies found in namespace ${namespace}"
    fi
}

# Main connectivity validation
main() {
    local connectivity_failed=0
    
    echo "Starting connectivity validation..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Get pods for testing
    local frontend_pod=$(get_app_pod "frontend" "$NAMESPACE")
    local backend_pod=$(get_app_pod "backend" "$NAMESPACE")
    
    if [[ -z "$frontend_pod" ]]; then
        echo "ERROR: Frontend pod not found"
        exit 1
    fi
    
    if [[ -z "$backend_pod" ]]; then
        echo "ERROR: Backend pod not found"
        exit 1
    fi
    
    echo ""
    echo "Testing service discovery..."
    validate_service_discovery "$NAMESPACE"
    
    echo ""
    echo "Testing frontend connectivity..."
    
    # Test frontend to backend connectivity
    if ! test_service_connectivity "$frontend_pod" "backend" "$NAMESPACE" "3000"; then
        connectivity_failed=1
    fi
    
    # Test HTTP connectivity to backend API
    if ! test_http_connectivity "$frontend_pod" "http://backend.${NAMESPACE}.svc.cluster.local:3000/api/health" "$NAMESPACE"; then
        connectivity_failed=1
    fi
    
    echo ""
    echo "Testing backend connectivity..."
    
    # Test backend to database connectivity
    if ! test_database_connectivity "$backend_pod" "mysql" "3306" "$NAMESPACE"; then
        connectivity_failed=1
    fi
    
    echo ""
    echo "Testing network policies..."
    test_network_policies "$NAMESPACE"
    
    echo ""
    echo "----------------------------------------"
    
    if [[ $connectivity_failed -eq 0 ]]; then
        echo "✅ All connectivity tests passed"
        echo "Inter-service connectivity is healthy for deployment ${DEPLOYMENT_ID}"
        exit 0
    else
        echo "❌ Some connectivity tests failed"
        echo "Inter-service connectivity issues detected for deployment ${DEPLOYMENT_ID}"
        exit 1
    fi
}

# Run main function
main "$@"