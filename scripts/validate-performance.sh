#!/bin/bash

# Performance Baseline Validation Script
# Usage: ./validate-performance.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
PERFORMANCE_TIMEOUT=30
BASELINE_RESPONSE_TIME=2000  # milliseconds
BASELINE_CPU_USAGE=70        # percentage
BASELINE_MEMORY_USAGE=80     # percentage

echo "Validating performance baselines for ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

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

# Function to measure response time
measure_response_time() {
    local url=$1
    local timeout=${2:-30}
    local description=$3
    
    echo "Measuring response time for ${description}..."
    
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
        
        # Measure response time
        local response_time=$(curl -o /dev/null -s -w "%{time_total}" \
            --max-time ${timeout} \
            "http://localhost:${port}" 2>/dev/null || echo "0")
        
        # Convert to milliseconds
        response_time=$(echo "${response_time} * 1000" | bc 2>/dev/null || echo "0")
        
        # Clean up port-forward
        kill $pf_pid 2>/dev/null || true
        wait $pf_pid 2>/dev/null || true
    else
        # Measure external URL directly
        local response_time=$(curl -o /dev/null -s -w "%{time_total}" \
            --max-time ${timeout} \
            "${url}" 2>/dev/null || echo "0")
        
        # Convert to milliseconds
        response_time=$(echo "${response_time} * 1000" | bc 2>/dev/null || echo "0")
    fi
    
    echo "${response_time}"
}

# Function to test response time baseline
test_response_time_baseline() {
    local service_name=$1
    local endpoint=$2
    local baseline_ms=$3
    
    echo "Testing response time baseline for ${service_name}..."
    
    local service_url=$(get_service_url "$service_name" "$NAMESPACE")
    local response_time=$(measure_response_time "${service_url}${endpoint}" "$PERFORMANCE_TIMEOUT" "${service_name}")
    
    # Convert to integer for comparison
    response_time=${response_time%.*}
    
    if [[ $response_time -le $baseline_ms ]]; then
        echo "✓ ${service_name} response time: ${response_time}ms (baseline: ${baseline_ms}ms)"
        return 0
    else
        echo "WARNING: ${service_name} response time: ${response_time}ms (baseline: ${baseline_ms}ms)"
        return 1
    fi
}

# Function to get pod resource usage
get_pod_resource_usage() {
    local pod_name=$1
    local namespace=$2
    
    # Get metrics from metrics server
    local metrics=$(kubectl top pod ${pod_name} -n ${namespace} --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$metrics" ]]; then
        echo "0 0"
        return 1
    fi
    
    # Parse metrics: CPU and memory usage
    local cpu_usage=$(echo "$metrics" | awk '{print $2}')
    local memory_usage=$(echo "$metrics" | awk '{print $3}')
    
    # Convert to percentages
    # Remove 'm' from CPU and convert to percentage (assuming 1000m = 100%)
    cpu_usage=${cpu_usage%m}
    cpu_usage=$((cpu_usage / 10))
    
    # Remove 'Mi' from memory
    memory_usage=${memory_usage%Mi}
    
    echo "${cpu_usage} ${memory_usage}"
}

# Function to get pod resource limits
get_pod_resource_limits() {
    local pod_name=$1
    local namespace=$2
    
    # Get pod spec
    local pod_spec=$(kubectl get pod ${pod_name} -n ${namespace} -o json)
    
    # Extract resource limits
    local cpu_limit=$(echo "$pod_spec" | jq -r '.spec.containers[0].resources.limits.cpu // "0"')
    local memory_limit=$(echo "$pod_spec" | jq -r '.spec.containers[0].resources.limits.memory // "0"')
    
    # Convert to comparable units
    if [[ "$cpu_limit" == *"m" ]]; then
        cpu_limit=${cpu_limit%m}
        cpu_limit=$((cpu_limit / 10))  # Convert to percentage
    elif [[ "$cpu_limit" != "0" ]]; then
        cpu_limit=$((cpu_limit * 100))  # Convert cores to percentage
    fi
    
    if [[ "$memory_limit" == *"Mi" ]]; then
        memory_limit=${memory_limit%Mi}
    elif [[ "$memory_limit" == *"Gi" ]]; then
        memory_limit=$((${memory_limit%Gi} * 1024))
    fi
    
    echo "${cpu_limit} ${memory_limit}"
}

# Function to test resource usage baseline
test_resource_usage_baseline() {
    local app_name=$1
    local cpu_baseline=$2
    local memory_baseline=$3
    
    echo "Testing resource usage baseline for ${app_name}..."
    
    # Get pod for the application
    local pod_name=$(kubectl get pods \
        -l app=${app_name} \
        -n ${NAMESPACE} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$pod_name" ]]; then
        echo "WARNING: No pod found for ${app_name}"
        return 0
    fi
    
    # Get current resource usage
    local usage=$(get_pod_resource_usage "$pod_name" "$NAMESPACE")
    local cpu_usage=$(echo "$usage" | awk '{print $1}')
    local memory_usage=$(echo "$usage" | awk '{print $2}')
    
    # Get resource limits
    local limits=$(get_pod_resource_limits "$pod_name" "$NAMESPACE")
    local cpu_limit=$(echo "$limits" | awk '{print $1}')
    local memory_limit=$(echo "$limits" | awk '{print $2}')
    
    # Calculate usage percentage
    if [[ $cpu_limit -gt 0 ]]; then
        cpu_usage=$((cpu_usage * 100 / cpu_limit))
    fi
    
    if [[ $memory_limit -gt 0 ]]; then
        memory_usage=$((memory_usage * 100 / memory_limit))
    fi
    
    # Check against baselines
    local resource_failed=0
    
    if [[ $cpu_usage -le $cpu_baseline ]]; then
        echo "✓ ${app_name} CPU usage: ${cpu_usage}% (baseline: ${cpu_baseline}%)"
    else
        echo "WARNING: ${app_name} CPU usage: ${cpu_usage}% (baseline: ${cpu_baseline}%)"
        resource_failed=1
    fi
    
    if [[ $memory_usage -le $memory_baseline ]]; then
        echo "✓ ${app_name} Memory usage: ${memory_usage}% (baseline: ${memory_baseline}%)"
    else
        echo "WARNING: ${app_name} Memory usage: ${memory_usage}% (baseline: ${memory_baseline}%)"
        resource_failed=1
    fi
    
    return $resource_failed
}

# Function to test throughput
test_throughput() {
    local service_name=$1
    local endpoint=$2
    local requests=${3:-10}
    local concurrent=${4:-2}
    
    echo "Testing throughput for ${service_name} (${requests} requests, ${concurrent} concurrent)..."
    
    local service_url=$(get_service_url "$service_name" "$NAMESPACE")
    
    # Handle clusterip URLs
    if [[ "$service_url" == clusterip:* ]]; then
        local port=${service_url#clusterip:}
        
        # Set up port forwarding
        kubectl port-forward -n ${NAMESPACE} service/${service_name} ${port}:80 \
            >/dev/null 2>&1 &
        local pf_pid=$!
        
        sleep 2
        
        # Test throughput
        local success_count=0
        for ((i=1; i<=requests; i++)); do
            if curl -s -f --max-time 5 "http://localhost:${port}${endpoint}" >/dev/null 2>&1; then
                ((success_count++))
            fi
        done
        
        # Clean up port-forward
        kill $pf_pid 2>/dev/null || true
        wait $pf_pid 2>/dev/null || true
    else
        # Test external URL directly
        local success_count=0
        for ((i=1; i<=requests; i++)); do
            if curl -s -f --max-time 5 "${service_url}${endpoint}" >/dev/null 2>&1; then
                ((success_count++))
            fi
        done
    fi
    
    local success_rate=$((success_count * 100 / requests))
    
    if [[ $success_rate -ge 95 ]]; then
        echo "✓ ${service_name} throughput: ${success_count}/${requests} (${success_rate}%)"
        return 0
    else
        echo "WARNING: ${service_name} throughput: ${success_count}/${requests} (${success_rate}%)"
        return 1
    fi
}

# Function to test error rates
test_error_rates() {
    local service_name=$1
    local endpoint=$2
    local requests=${3:-20}
    
    echo "Testing error rates for ${service_name}..."
    
    local service_url=$(get_service_url "$service_name" "$NAMESPACE")
    local error_count=0
    
    # Handle clusterip URLs
    if [[ "$service_url" == clusterip:* ]]; then
        local port=${service_url#clusterip:}
        
        # Set up port forwarding
        kubectl port-forward -n ${NAMESPACE} service/${service_name} ${port}:80 \
            >/dev/null 2>&1 &
        local pf_pid=$!
        
        sleep 2
        
        # Test error rates
        for ((i=1; i<=requests; i++)); do
            if ! curl -s -f --max-time 5 "http://localhost:${port}${endpoint}" >/dev/null 2>&1; then
                ((error_count++))
            fi
        done
        
        # Clean up port-forward
        kill $pf_pid 2>/dev/null || true
        wait $pf_pid 2>/dev/null || true
    else
        # Test external URL directly
        for ((i=1; i<=requests; i++)); do
            if ! curl -s -f --max-time 5 "${service_url}${endpoint}" >/dev/null 2>&1; then
                ((error_count++))
            fi
        done
    fi
    
    local error_rate=$((error_count * 100 / requests))
    
    if [[ $error_rate -le 5 ]]; then
        echo "✓ ${service_name} error rate: ${error_count}/${requests} (${error_rate}%)"
        return 0
    else
        echo "WARNING: ${service_name} error rate: ${error_count}/${requests} (${error_rate}%)"
        return 1
    fi
}

# Main performance validation logic
main() {
    local performance_failed=0
    
    echo "Starting performance validation..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "Deployment ID: ${DEPLOYMENT_ID}"
    echo "Baselines:"
    echo "  Response Time: ${BASELINE_RESPONSE_TIME}ms"
    echo "  CPU Usage: ${BASELINE_CPU_USAGE}%"
    echo "  Memory Usage: ${BASELINE_MEMORY_USAGE}%"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    echo ""
    echo "Response Time Tests:"
    echo "-------------------"
    
    # Test response time baselines
    if ! test_response_time_baseline "frontend" "/" "$BASELINE_RESPONSE_TIME"; then
        performance_failed=1
    fi
    
    if ! test_response_time_baseline "backend" "/api/health" "$BASELINE_RESPONSE_TIME"; then
        performance_failed=1
    fi
    
    echo ""
    echo "Resource Usage Tests:"
    echo "--------------------"
    
    # Test resource usage baselines
    if ! test_resource_usage_baseline "frontend" "$BASELINE_CPU_USAGE" "$BASELINE_MEMORY_USAGE"; then
        performance_failed=1
    fi
    
    if ! test_resource_usage_baseline "backend" "$BASELINE_CPU_USAGE" "$BASELINE_MEMORY_USAGE"; then
        performance_failed=1
    fi
    
    echo ""
    echo "Throughput Tests:"
    echo "-----------------"
    
    # Test throughput
    if ! test_throughput "frontend" "/" 10 2; then
        performance_failed=1
    fi
    
    if ! test_throughput "backend" "/api/health" 10 2; then
        performance_failed=1
    fi
    
    echo ""
    echo "Error Rate Tests:"
    echo "----------------"
    
    # Test error rates
    if ! test_error_rates "frontend" "/" 20; then
        performance_failed=1
    fi
    
    if ! test_error_rates "backend" "/api/health" 20; then
        performance_failed=1
    fi
    
    echo ""
    echo "----------------------------------------"
    
    if [[ $performance_failed -eq 0 ]]; then
        echo "✅ All performance tests passed"
        echo "Deployment ${DEPLOYMENT_ID} meets performance baselines"
        exit 0
    else
        echo "❌ Some performance tests failed"
        echo "Deployment ${DEPLOYMENT_ID} exceeds performance baselines"
        exit 1
    fi
}

# Run main function
main "$@"