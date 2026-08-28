#!/bin/bash

# Resource Utilization Monitoring Script
# Usage: ./monitor-resources.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
WARNING_CPU=80
WARNING_MEMORY=80
CRITICAL_CPU=90
CRITICAL_MEMORY=90

echo "Monitoring resource utilization for ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

# Function to get pod resource usage
get_pod_usage() {
    local pod_name=$1
    local namespace=$2
    
    # Get metrics from metrics server
    local metrics=$(kubectl top pod ${pod_name} -n ${namespace} --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$metrics" ]]; then
        echo "WARNING: No metrics available for pod ${pod_name}"
        return 1
    fi
    
    # Parse metrics: CPU and memory usage
    local cpu_usage=$(echo "$metrics" | awk '{print $2}')
    local memory_usage=$(echo "$metrics" | awk '{print $3}')
    
    echo "${cpu_usage} ${memory_usage}"
}

# Function to get pod resource requests/limits
get_pod_resources() {
    local pod_name=$1
    local namespace=$2
    
    # Get pod spec
    local pod_spec=$(kubectl get pod ${pod_name} -n ${namespace} -o json)
    
    # Extract resource requests and limits
    local cpu_request=$(echo "$pod_spec" | jq -r '.spec.containers[0].resources.requests.cpu // "0"')
    local cpu_limit=$(echo "$pod_spec" | jq -r '.spec.containers[0].resources.limits.cpu // "0"')
    local memory_request=$(echo "$pod_spec" | jq -r '.spec.containers[0].resources.requests.memory // "0"')
    local memory_limit=$(echo "$pod_spec" | jq -r '.spec.containers[0].resources.limits.memory // "0"')
    
    echo "${cpu_request} ${cpu_limit} ${memory_request} ${memory_limit}"
}

# Function to convert CPU units to millicores
convert_cpu_to_millicores() {
    local cpu_value=$1
    
    if [[ "$cpu_value" == *"m" ]]; then
        echo "${cpu_value%m}"
    elif [[ "$cpu_value" == *"" ]]; then
        echo $((${cpu_value} * 1000))
    else
        echo "0"
    fi
}

# Function to convert memory units to MB
convert_memory_to_mb() {
    local memory_value=$1
    
    if [[ "$memory_value" == *"Mi" ]]; then
        echo "${memory_value%Mi}"
    elif [[ "$memory_value" == *"Gi" ]]; then
        echo $((${memory_value%Gi} * 1024))
    elif [[ "$memory_value" == *"Ki" ]]; then
        echo $((${memory_value%Ki} / 1024))
    else
        echo "0"
    fi
}

# Function to check resource thresholds
check_resource_thresholds() {
    local usage=$1
    local limit=$2
    local resource_type=$3
    local pod_name=$4
    
    if [[ "$limit" == "0" ]]; then
        echo "WARNING: No ${resource_type} limit set for pod ${pod_name}"
        return 0
    fi
    
    local usage_percent=$((usage * 100 / limit))
    
    if [[ $usage_percent -ge $CRITICAL_CPU && "$resource_type" == "CPU" ]] || \
       [[ $usage_percent -ge $CRITICAL_MEMORY && "$resource_type" == "Memory" ]]; then
        echo "CRITICAL: ${resource_type} usage is ${usage_percent}% for pod ${pod_name}"
        return 2
    elif [[ $usage_percent -ge $WARNING_CPU && "$resource_type" == "CPU" ]] || \
         [[ $usage_percent -ge $WARNING_MEMORY && "$resource_type" == "Memory" ]]; then
        echo "WARNING: ${resource_type} usage is ${usage_percent}% for pod ${pod_name}"
        return 1
    else
        echo "OK: ${resource_type} usage is ${usage_percent}% for pod ${pod_name}"
        return 0
    fi
}

# Function to monitor single pod
monitor_pod() {
    local pod_name=$1
    local namespace=$2
    
    echo "Monitoring pod: ${pod_name}"
    
    # Get resource usage
    local usage=$(get_pod_usage "$pod_name" "$namespace")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local cpu_usage=$(convert_cpu_to_millicores "$(echo "$usage" | awk '{print $1}')")
    local memory_usage=$(convert_memory_to_mb "$(echo "$usage" | awk '{print $2}')")
    
    # Get resource limits
    local resources=$(get_pod_resources "$pod_name" "$namespace")
    local cpu_request=$(convert_cpu_to_millicores "$(echo "$resources" | awk '{print $1}')")
    local cpu_limit=$(convert_cpu_to_millicores "$(echo "$resources" | awk '{print $2}')")
    local memory_request=$(convert_memory_to_mb "$(echo "$resources" | awk '{print $3}')")
    local memory_limit=$(convert_memory_to_mb "$(echo "$resources" | awk '{print $4}')")
    
    echo "  CPU Usage: ${cpu_usage}m (Request: ${cpu_request}m, Limit: ${cpu_limit}m)"
    echo "  Memory Usage: ${memory_usage}Mi (Request: ${memory_request}Mi, Limit: ${memory_limit}Mi)"
    
    # Check thresholds
    local threshold_status=0
    
    if [[ $cpu_limit -gt 0 ]]; then
        check_resource_thresholds "$cpu_usage" "$cpu_limit" "CPU" "$pod_name"
        threshold_status=$((threshold_status + $?))
    fi
    
    if [[ $memory_limit -gt 0 ]]; then
        check_resource_thresholds "$memory_usage" "$memory_limit" "Memory" "$pod_name"
        threshold_status=$((threshold_status + $?))
    fi
    
    return $threshold_status
}

# Function to get namespace resource quotas
check_resource_quotas() {
    local namespace=$1
    
    echo "Checking resource quotas..."
    
    # Get resource quota if exists
    local quota=$(kubectl get resourcequota -n ${namespace} -o json 2>/dev/null || echo "")
    
    if [[ -z "$quota" ]]; then
        echo "INFO: No resource quota defined for namespace ${namespace}"
        return 0
    fi
    
    # Parse quota
    local hard_cpu=$(echo "$quota" | jq -r '.items[0].status.hard["limits.cpu"] // "0"')
    local used_cpu=$(echo "$quota" | jq -r '.items[0].status.used["limits.cpu"] // "0"')
    local hard_memory=$(echo "$quota" | jq -r '.items[0].status.hard["limits.memory"] // "0"')
    local used_memory=$(echo "$quota" | jq -r '.items[0].status.used["limits.memory"] // "0"')
    
    if [[ "$hard_cpu" != "0" ]]; then
        local cpu_percent=$((${used_cpu%?} * 100 / ${hard_cpu%?}))
        echo "  CPU Quota: ${used_cpu} / ${hard_cpu} (${cpu_percent}%)"
    fi
    
    if [[ "$hard_memory" != "0" ]]; then
        local memory_used_mb=$(convert_memory_to_mb "$used_memory")
        local memory_hard_mb=$(convert_memory_to_mb "$hard_memory")
        local memory_percent=$((memory_used_mb * 100 / memory_hard_mb))
        echo "  Memory Quota: ${memory_used_mb}Mi / ${memory_hard_mb}Mi (${memory_percent}%)"
    fi
}

# Function to check node resources
check_node_resources() {
    local namespace=$1
    
    echo "Checking node resources..."
    
    # Get nodes running pods in this namespace
    local nodes=$(kubectl get pods -n ${namespace} -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u)
    
    for node in $nodes; do
        echo "  Node: ${node}"
        
        # Get node capacity and allocatable
        local capacity=$(kubectl describe node ${node} | grep -A 5 "Capacity:")
        local allocatable=$(kubectl describe node ${node} | grep -A 5 "Allocatable:")
        
        echo "    Capacity:"
        echo "$capacity" | grep -E "(cpu|memory)" | sed 's/^/      /'
        
        echo "    Allocatable:"
        echo "$allocatable" | grep -E "(cpu|memory)" | sed 's/^/      /'
        
        # Get node conditions
        local conditions=$(kubectl get node ${node} -o jsonpath='{.status.conditions[*].type}:{.status}' | tr ' ' '\n')
        
        while IFS=':' read -r condition status; do
            if [[ "$status" == "True" && "$condition" != "Ready" ]]; then
                echo "    WARNING: Node condition ${condition} is ${status}"
            fi
        done <<< "$conditions"
    done
}

# Main monitoring logic
main() {
    local monitoring_failed=0
    
    echo "Starting resource monitoring..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "Warning thresholds: CPU ${WARNING_CPU}%, Memory ${WARNING_MEMORY}%"
    echo "Critical thresholds: CPU ${CRITICAL_CPU}%, Memory ${CRITICAL_MEMORY}%"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Get all pods in namespace
    local pods=$(kubectl get pods -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$pods" ]]; then
        echo "ERROR: No pods found in namespace ${NAMESPACE}"
        exit 1
    fi
    
    echo ""
    echo "Pod Resource Usage:"
    echo "-------------------"
    
    # Monitor each pod
    for pod in $pods; do
        echo ""
        monitor_pod "$pod" "$NAMESPACE"
        local pod_status=$?
        
        if [[ $pod_status -gt 1 ]]; then
            monitoring_failed=1
        fi
    done
    
    echo ""
    echo "Resource Quotas:"
    echo "---------------"
    check_resource_quotas "$NAMESPACE"
    
    echo ""
    echo "Node Resources:"
    echo "---------------"
    check_node_resources "$NAMESPACE"
    
    echo ""
    echo "----------------------------------------"
    
    if [[ $monitoring_failed -eq 0 ]]; then
        echo "✅ Resource monitoring completed successfully"
        echo "All resources are within acceptable thresholds for deployment ${DEPLOYMENT_ID}"
        exit 0
    else
        echo "❌ Resource monitoring detected critical issues"
        echo "Some resources exceed critical thresholds for deployment ${DEPLOYMENT_ID}"
        exit 1
    fi
}

# Run main function
main "$@"