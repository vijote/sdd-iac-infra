#!/bin/bash

# Deployment Smoke Tests Script
# Usage: ./smoke-tests.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
SMOKE_TEST_TIMEOUT=60

echo "Running smoke tests for ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

# Function to get service URL
get_service_url() {
    local service_name=$1
    local namespace=$2
    
    # Try to get LoadBalancer hostname first
    local hostname=$(kubectl get service ${service_name} \
        -n ${namespace} \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [[ -n "$hostname" ]]; then
        echo "http://${hostname}"
        return 0
    fi
    
    # Try to get LoadBalancer IP
    local ip=$(kubectl get service ${service_name} \
        -n ${namespace} \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [[ -n "$ip" ]]; then
        echo "http://${ip}"
        return 0
    fi
    
    # For ClusterIP services, use port-forwarding
    local port=$(kubectl get service ${service_name} \
        -n ${namespace} \
        -o jsonpath='{.spec.ports[0].port}')
    
    echo "clusterip:${port}"
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    local timeout=${3:-30}
    local description=$4
    
    echo "Testing ${description}: ${url}"
    
    # Handle clusterip URLs
    if [[ "$url" == clusterip:* ]]; then
        local port=${url#clusterip:}
        local service_name=$(echo "$description" | awk '{print $1}')
        
        # Set up port forwarding
        kubectl port-forward -n ${NAMESPACE} service/${service_name} ${port}:80 \
            >/dev/null 2>&1 &
        local pf_pid=$!
        
        # Wait for port-forward to be ready
        sleep 2
        
        # Test the endpoint
        local response=$(curl -s -w "%{http_code}" \
            --max-time ${timeout} \
            "http://localhost:${port}" || echo "000")
        
        # Clean up port-forward
        kill $pf_pid 2>/dev/null || true
        wait $pf_pid 2>/dev/null || true
    else
        # Test external URL directly
        local response=$(curl -s -w "%{http_code}" \
            --max-time ${timeout} \
            "${url}" || echo "000")
    fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" == "$expected_status" ]]; then
        echo "✓ ${description} - HTTP ${http_code}"
        return 0
    else
        echo "ERROR: ${description} - HTTP ${http_code} (expected ${expected_status})"
        echo "Response body: ${body}"
        return 1
    fi
}

# Function to test API endpoints
test_api_endpoints() {
    local base_url=$1
    
    echo "Testing API endpoints..."
    
    local api_tests=(
        "${base_url}/api/health:200:Health Check"
        "${base_url}/api/users:200:Users List"
        "${base_url}/api/posts:200:Posts List"
    )
    
    local api_failed=0
    
    for test in "${api_tests[@]}"; do
        IFS=':' read -r endpoint expected_status description <<< "$test"
        
        if ! test_http_endpoint "${endpoint}" "$expected_status" "$SMOKE_TEST_TIMEOUT" "$description"; then
            api_failed=1
        fi
    done
    
    return $api_failed
}

# Function to test database connectivity from application
test_app_database_connectivity() {
    local namespace=$1
    
    echo "Testing application database connectivity..."
    
    # Get backend pod
    local backend_pod=$(kubectl get pods \
        -l app=backend \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$backend_pod" ]]; then
        echo "ERROR: Backend pod not found"
        return 1
    fi
    
    # Test database connectivity via API
    local backend_url=$(get_service_url "backend" "$namespace")
    
    if [[ "$backend_url" == clusterip:* ]]; then
        # Use port-forwarding for clusterip
        local port=${backend_url#clusterip:}
        kubectl port-forward -n ${namespace} service/backend ${port}:80 >/dev/null 2>&1 &
        local pf_pid=$!
        sleep 2
        
        local response=$(curl -s -w "%{http_code}" \
            --max-time $SMOKE_TEST_TIMEOUT \
            "http://localhost:${port}/api/health/db" || echo "000")
        
        kill $pf_pid 2>/dev/null || true
        wait $pf_pid 2>/dev/null || true
    else
        local response=$(curl -s -w "%{http_code}" \
            --max-time $SMOKE_TEST_TIMEOUT \
            "${backend_url}/api/health/db" || echo "000")
    fi
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        echo "✓ Application database connectivity - HTTP ${http_code}"
        return 0
    else
        echo "ERROR: Application database connectivity - HTTP ${http_code}"
        return 1
    fi
}

# Function to test service discovery
test_service_discovery() {
    local namespace=$1
    
    echo "Testing service discovery..."
    
    # Get frontend pod
    local frontend_pod=$(kubectl get pods \
        -l app=frontend \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$frontend_pod" ]]; then
        echo "ERROR: Frontend pod not found"
        return 1
    fi
    
    # Test DNS resolution for backend service
    if kubectl exec ${frontend_pod} -n ${namespace} -- \
        nslookup backend.${namespace}.svc.cluster.local >/dev/null 2>&1; then
        echo "✓ Service discovery - Backend DNS resolution successful"
    else
        echo "ERROR: Service discovery - Backend DNS resolution failed"
        return 1
    fi
    
    # Test DNS resolution for database service
    if kubectl exec ${frontend_pod} -n ${namespace} -- \
        nslookup mysql.${namespace}.svc.cluster.local >/dev/null 2>&1; then
        echo "✓ Service discovery - MySQL DNS resolution successful"
    else
        echo "ERROR: Service discovery - MySQL DNS resolution failed"
        return 1
    fi
    
    return 0
}

# Function to test load balancing
test_load_balancing() {
    local namespace=$1
    
    echo "Testing load balancing..."
    
    # Check if service has multiple endpoints
    local backend_endpoints=$(kubectl get endpoints backend \
        -n ${namespace} \
        -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)
    
    if [[ $backend_endpoints -gt 1 ]]; then
        echo "✓ Load balancing - Backend has ${backend_endpoints} endpoints"
    else
        echo "INFO: Load balancing - Backend has ${backend_endpoints} endpoint(s)"
    fi
    
    local frontend_endpoints=$(kubectl get endpoints frontend \
        -n ${namespace} \
        -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)
    
    if [[ $frontend_endpoints -gt 1 ]]; then
        echo "✓ Load balancing - Frontend has ${frontend_endpoints} endpoints"
    else
        echo "INFO: Load balancing - Frontend has ${frontend_endpoints} endpoint(s)"
    fi
    
    return 0
}

# Function to test configuration
test_configuration() {
    local namespace=$1
    
    echo "Testing application configuration..."
    
    # Check if ConfigMaps are mounted
    local frontend_pod=$(kubectl get pods \
        -l app=frontend \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$frontend_pod" ]]; then
        if kubectl exec ${frontend_pod} -n ${namespace} -- \
            test -f /app/config/environment.json >/dev/null 2>&1; then
            echo "✓ Configuration - Frontend ConfigMap mounted"
        else
            echo "WARNING: Configuration - Frontend ConfigMap not found"
        fi
    fi
    
    # Check if Secrets are mounted
    local backend_pod=$(kubectl get pods \
        -l app=backend \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$backend_pod" ]]; then
        if kubectl exec ${backend_pod} -n ${namespace} -- \
            test -f /app/secrets/database.json >/dev/null 2>&1; then
            echo "✓ Configuration - Backend Secrets mounted"
        else
            echo "WARNING: Configuration - Backend Secrets not found"
        fi
    fi
    
    return 0
}

# Main smoke test logic
main() {
    local smoke_failed=0
    
    echo "Starting smoke tests..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "Deployment ID: ${DEPLOYMENT_ID}"
    echo "Timeout: ${SMOKE_TEST_TIMEOUT}s"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Get service URLs
    local frontend_url=$(get_service_url "frontend" "$NAMESPACE")
    local backend_url=$(get_service_url "backend" "$NAMESPACE")
    
    echo ""
    echo "Service URLs:"
    echo "  Frontend: ${frontend_url}"
    echo "  Backend: ${backend_url}"
    echo ""
    
    # Test frontend health
    if ! test_http_endpoint "${frontend_url}" "200" "$SMOKE_TEST_TIMEOUT" "Frontend Health"; then
        smoke_failed=1
    fi
    
    # Test backend health
    if ! test_http_endpoint "${backend_url}" "200" "$SMOKE_TEST_TIMEOUT" "Backend Health"; then
        smoke_failed=1
    fi
    
    # Test API endpoints
    if ! test_api_endpoints "$backend_url"; then
        smoke_failed=1
    fi
    
    # Test application database connectivity
    if ! test_app_database_connectivity "$NAMESPACE"; then
        smoke_failed=1
    fi
    
    # Test service discovery
    if ! test_service_discovery "$NAMESPACE"; then
        smoke_failed=1
    fi
    
    # Test load balancing
    if ! test_load_balancing "$NAMESPACE"; then
        smoke_failed=1
    fi
    
    # Test configuration
    if ! test_configuration "$NAMESPACE"; then
        smoke_failed=1
    fi
    
    echo ""
    echo "----------------------------------------"
    
    if [[ $smoke_failed -eq 0 ]]; then
        echo "✅ All smoke tests passed"
        echo "Deployment ${DEPLOYMENT_ID} is ready for use"
        exit 0
    else
        echo "❌ Some smoke tests failed"
        echo "Deployment ${DEPLOYMENT_ID} has issues that need attention"
        exit 1
    fi
}

# Run main function
main "$@"