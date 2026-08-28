#!/bin/bash

# Pipeline Metrics Collection Script
# Usage: ./metrics.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
METRICS_FILE="metrics-${DEPLOYMENT_ID}.json"

echo "Collecting pipeline metrics for ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

# Function to collect deployment metrics
collect_deployment_metrics() {
    local namespace=$1
    local deployment_id=$2
    
    echo "Collecting deployment metrics..."
    
    # Get deployment information
    local deployments=$(kubectl get deployments -n ${namespace} -o json)
    
    local deployment_metrics=$(echo "$deployments" | jq -r '
    {
        "total_deployments": (.items | length),
        "ready_deployments": [.items[] | select(.status.readyReplicas == .spec.replicas)] | length,
        "unavailable_replicas": [.items[] | .status.unavailableReplicas] | add,
        "total_replicas": [.items[] | .spec.replicas] | add,
        "ready_replicas": [.items[] | .status.readyReplicas] | add
    }')
    
    echo "$deployment_metrics"
}

# Function to collect resource metrics
collect_resource_metrics() {
    local namespace=$1
    
    echo "Collecting resource metrics..."
    
    # Get pod resource usage
    local pod_metrics=$(kubectl top pods -n ${namespace} --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$pod_metrics" ]]; then
        echo '{"cpu_usage": 0, "memory_usage": 0, "pod_count": 0}'
        return
    fi
    
    local total_cpu=0
    local total_memory=0
    local pod_count=0
    
    while read -r _ cpu memory; do
        # Remove 'm' from CPU and 'Mi' from memory
        cpu=${cpu%m}
        memory=${memory%Mi}
        
        total_cpu=$((total_cpu + cpu))
        total_memory=$((total_memory + memory))
        pod_count=$((pod_count + 1))
    done <<< "$pod_metrics"
    
    jq -n \
        --argjson cpu "$total_cpu" \
        --argjson memory "$total_memory" \
        --argjson count "$pod_count" \
        '{
            cpu_usage: $cpu,
            memory_usage: $memory,
            pod_count: $count
        }'
}

# Function to collect service metrics
collect_service_metrics() {
    local namespace=$1
    
    echo "Collecting service metrics..."
    
    # Get service information
    local services=$(kubectl get services -n ${namespace} -o json)
    
    local service_metrics=$(echo "$services" | jq -r '
    {
        "total_services": (.items | length),
        "loadbalancer_services": [.items[] | select(.spec.type == "LoadBalancer")] | length,
        "clusterip_services": [.items[] | select(.spec.type == "ClusterIP")] | length,
        "nodeport_services": [.items[] | select(.spec.type == "NodePort")] | length,
        "services_with_endpoints": [.items[] | select(.metadata.name as $name | $name in ([
            .items[].metadata.name
        ]))] | length
    }')
    
    echo "$service_metrics"
}

# Function to collect pipeline metrics
collect_pipeline_metrics() {
    local deployment_id=$1
    
    echo "Collecting pipeline metrics..."
    
    # Get pipeline run information
    local run_info=$(gh run list --workflow=application-deployment.yml --limit=1 --json createdAt,status,conclusion,databaseId 2>/dev/null || echo "{}")
    
    if [[ "$run_info" == "{}" ]]; then
        echo '{"status": "unknown", "duration": 0, "conclusion": null}'
        return
    fi
    
    # Calculate duration (simplified - would need start/end times in real implementation)
    local duration=0
    
    echo "$run_info" | jq -r --argjson dur "$duration" '
    {
        "status": .[0].status,
        "duration": $dur,
        "conclusion": .[0].conclusion,
        "run_id": .[0].databaseId
    }'
}

# Function to collect error metrics
collect_error_metrics() {
    local namespace=$1
    local deployment_id=$2
    
    echo "Collecting error metrics..."
    
    # Get recent events
    local events=$(kubectl get events -n ${namespace} --sort-by='.lastTimestamp' -o json)
    
    local error_count=$(echo "$events" | jq -r '[.items[] | select(.type == "Warning")] | length')
    local recent_errors=$(echo "$events" | jq -r '[.items[] | select(.type == "Warning" and (.lastTimestamp | fromdateiso8601) > (now - 3600))] | length')
    
    jq -n \
        --argjson total "$error_count" \
        --argjson recent "$recent_errors" \
        '{
            total_errors: $total,
            recent_errors: $recent,
            error_rate: ($recent / 10 | * 100)
        }'
}

# Function to collect performance metrics
collect_performance_metrics() {
    local namespace=$1
    
    echo "Collecting performance metrics..."
    
    # Get node metrics
    local node_metrics=$(kubectl top nodes --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$node_metrics" ]]; then
        echo '{"node_cpu_usage": 0, "node_memory_usage": 0, "node_count": 0}'
        return
    fi
    
    local total_cpu=0
    local total_memory=0
    local node_count=0
    
    while read -r node cpu memory _; do
        # Remove '%' from CPU and convert to millicores
        cpu=${cpu%\%}
        cpu=$((cpu * 10))
        
        # Remove 'Mi' from memory
        memory=${memory%Mi}
        
        total_cpu=$((total_cpu + cpu))
        total_memory=$((total_memory + memory))
        node_count=$((node_count + 1))
    done <<< "$node_metrics"
    
    jq -n \
        --argjson cpu "$total_cpu" \
        --argjson memory "$total_memory" \
        --argjson count "$node_count" \
        '{
            node_cpu_usage: $cpu,
            node_memory_usage: $memory,
            node_count: $count
        }'
}

# Function to generate metrics report
generate_metrics_report() {
    local namespace=$1
    local deployment_id=$2
    local environment=$3
    
    echo "Generating metrics report..."
    
    # Collect all metrics
    local deployment_metrics=$(collect_deployment_metrics "$namespace" "$deployment_id")
    local resource_metrics=$(collect_resource_metrics "$namespace")
    local service_metrics=$(collect_service_metrics "$namespace")
    local pipeline_metrics=$(collect_pipeline_metrics "$deployment_id")
    local error_metrics=$(collect_error_metrics "$namespace" "$deployment_id")
    local performance_metrics=$(collect_performance_metrics "$namespace")
    
    # Create comprehensive metrics report
    cat > "$METRICS_FILE" << EOF
{
  "deployment_id": "${deployment_id}",
  "environment": "${environment}",
  "namespace": "${namespace}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "deployment_metrics": ${deployment_metrics},
  "resource_metrics": ${resource_metrics},
  "service_metrics": ${service_metrics},
  "pipeline_metrics": ${pipeline_metrics},
  "error_metrics": ${error_metrics},
  "performance_metrics": ${performance_metrics}
}
EOF
    
    echo "✓ Metrics report generated: ${METRICS_FILE}"
    
    # Display summary
    echo ""
    echo "Metrics Summary:"
    echo "---------------"
    echo "Deployments: $(echo "$deployment_metrics" | jq -r '.ready_deployments')/$(echo "$deployment_metrics" | jq -r '.total_deployments') ready"
    echo "Pods: $(echo "$resource_metrics" | jq -r '.pod_count') pods"
    echo "CPU Usage: $(echo "$resource_metrics" | jq -r '.cpu_usage')m"
    echo "Memory Usage: $(echo "$resource_metrics" | jq -r '.memory_usage')Mi"
    echo "Services: $(echo "$service_metrics" | jq -r '.total_services') services"
    echo "Errors: $(echo "$error_metrics" | jq -r '.recent_errors') recent errors"
    echo "Pipeline Status: $(echo "$pipeline_metrics" | jq -r '.status')"
}

# Function to send metrics to monitoring system
send_metrics() {
    local metrics_file=$1
    
    echo "Sending metrics to monitoring system..."
    
    # This would integrate with your monitoring system
    # For example: Prometheus, Datadog, CloudWatch, etc.
    
    if [[ -n "${MONITORING_WEBHOOK:-}" ]]; then
        curl -X POST "${MONITORING_WEBHOOK}" \
            -H 'Content-Type: application/json' \
            -d @"${metrics_file}" \
            2>/dev/null || echo "Failed to send metrics to webhook"
    fi
    
    # Example: Send to CloudWatch
    if command -v aws >/dev/null 2>&1; then
        # Extract key metrics and send to CloudWatch
        local cpu_usage=$(jq -r '.resource_metrics.cpu_usage' "$metrics_file")
        local memory_usage=$(jq -r '.resource_metrics.memory_usage' "$metrics_file")
        local error_count=$(jq -r '.error_metrics.recent_errors' "$metrics_file")
        
        aws cloudwatch put-metric-data \
            --namespace "SDD/Pipeline" \
            --metric-data \
            Name=CPUUsage,Value=$cpu_usage,Unit=MilliCores \
            Name=MemoryUsage,Value=$memory_usage,Unit=Megabytes \
            Name=ErrorCount,Value=$error_count,Unit=Count \
            2>/dev/null || echo "Failed to send metrics to CloudWatch"
    fi
}

# Main metrics collection logic
main() {
    echo "Starting metrics collection..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "Deployment ID: ${DEPLOYMENT_ID}"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Generate metrics report
    generate_metrics_report "$NAMESPACE" "$DEPLOYMENT_ID" "$ENVIRONMENT"
    
    # Send metrics to monitoring system
    send_metrics "$METRICS_FILE"
    
    echo ""
    echo "----------------------------------------"
    echo "✅ Metrics collection completed"
    echo "Report saved to: ${METRICS_FILE}"
}

# Run main function
main "$@"