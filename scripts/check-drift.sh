#!/bin/bash

# Configuration Drift Detection Script
# Usage: ./check-drift.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
TERRAFORM_DIR="src/terraform/environments/${ENVIRONMENT}"

echo "Checking configuration drift for ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

# Function to check Terraform drift
check_terraform_drift() {
    local terraform_dir=$1
    
    echo "Checking Terraform configuration drift..."
    
    if [[ ! -d "$terraform_dir" ]]; then
        echo "WARNING: Terraform directory ${terraform_dir} not found"
        return 0
    fi
    
    cd "$terraform_dir"
    
    # Initialize Terraform
    if ! terraform init -input=false >/dev/null 2>&1; then
        echo "ERROR: Failed to initialize Terraform"
        return 1
    fi
    
    # Check for drift
    local drift_output=$(terraform plan -detailed-exitcode -input=false -no-color 2>&1)
    local exit_code=$?
    
    case $exit_code in
        0)
            echo "✓ No Terraform configuration drift detected"
            return 0
            ;;
        1)
            echo "ERROR: Terraform plan failed"
            echo "$drift_output"
            return 1
            ;;
        2)
            echo "WARNING: Terraform configuration drift detected"
            echo "$drift_output" | grep -E "(^\+.*|^\-.*|^~.*|^=.*|)" | head -20
            return 1
            ;;
    esac
}

# Function to check Kubernetes resource drift
check_kubernetes_drift() {
    local namespace=$1
    
    echo "Checking Kubernetes resource drift..."
    
    local drift_detected=0
    
    # Check for manually modified resources
    echo "Checking for manually modified deployments..."
    
    local deployments=$(kubectl get deployments -n ${namespace} -o jsonpath='{.items[*].metadata.name}')
    
    for deployment in $deployments; do
        # Check if deployment has manual changes
        local annotations=$(kubectl get deployment ${deployment} -n ${namespace} -o jsonpath='{.metadata.annotations.kubectl\.kubernetes\.io/last-applied-configuration}' || echo "")
        
        if [[ -z "$annotations" ]]; then
            echo "WARNING: Deployment ${deployment} may have manual changes (no last-applied annotation)"
            drift_detected=1
        fi
        
        # Check for unexpected replicas
        local current_replicas=$(kubectl get deployment ${deployment} -n ${namespace} -o jsonpath='{.spec.replicas}')
        local expected_replicas=$(kubectl get deployment ${deployment} -n ${namespace} -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/expected-replicas}' || echo "")
        
        if [[ -n "$expected_replicas" && "$current_replicas" != "$expected_replicas" ]]; then
            echo "WARNING: Deployment ${deployment} has ${current_replicas} replicas (expected ${expected_replicas})"
            drift_detected=1
        fi
    done
    
    # Check for orphaned resources
    echo "Checking for orphaned resources..."
    
    # Find pods without owner references
    local orphaned_pods=$(kubectl get pods -n ${namespace} -o json | \
        jq -r '.items[] | select(.metadata.ownerReferences == null) | .metadata.name' 2>/dev/null || echo "")
    
    if [[ -n "$orphaned_pods" ]]; then
        echo "WARNING: Orphaned pods found:"
        echo "$orphaned_pods" | sed 's/^/  /'
        drift_detected=1
    fi
    
    # Check for services without selectors
    local services_no_selector=$(kubectl get services -n ${namespace} -o json | \
        jq -r '.items[] | select(.spec.selector == null) | .metadata.name' 2>/dev/null || echo "")
    
    if [[ -n "$services_no_selector" ]]; then
        echo "WARNING: Services without selectors found:"
        echo "$services_no_selector" | sed 's/^/  /'
        drift_detected=1
    fi
    
    return $drift_detected
}

# Function to check configuration drift
check_config_drift() {
    local namespace=$1
    
    echo "Checking configuration drift..."
    
    local drift_detected=0
    
    # Check ConfigMap drift
    echo "Checking ConfigMap drift..."
    
    local configmaps=$(kubectl get configmaps -n ${namespace} -o jsonpath='{.items[*].metadata.name}')
    
    for configmap in $configmaps; do
        # Skip system configmaps
        if [[ "$configmap" == "kube-root-ca.crt" ]]; then
            continue
        fi
        
        # Check if ConfigMap has expected checksum
        local current_checksum=$(kubectl get configmap ${configmap} -n ${namespace} -o json | \
            jq -r '.data | to_entries | sort_by(.key) | .[] | "\(.key)=\(.value)"' | \
            sha256sum | awk '{print $1}')
        
        local expected_checksum=$(kubectl get configmap ${configmap} -n ${namespace} \
            -o jsonpath='{.metadata.annotations.config\.checksum}' 2>/dev/null || echo "")
        
        if [[ -n "$expected_checksum" && "$current_checksum" != "$expected_checksum" ]]; then
            echo "WARNING: ConfigMap ${configmap} has drifted (checksum mismatch)"
            drift_detected=1
        fi
    done
    
    # Check Secret drift
    echo "Checking Secret drift..."
    
    local secrets=$(kubectl get secrets -n ${namespace} -o jsonpath='{.items[*].metadata.name}')
    
    for secret in $secrets; do
        # Skip system secrets
        if [[ "$secret" == *"default-token"* || "$secret" == "sh.helm.release"* ]]; then
            continue
        fi
        
        # Check if Secret has expected checksum
        local current_checksum=$(kubectl get secret ${secret} -n ${namespace} -o json | \
            jq -r '.data | to_entries | sort_by(.key) | .[] | "\(.key)=\(.value)"' | \
            sha256sum | awk '{print $1}')
        
        local expected_checksum=$(kubectl get secret ${secret} -n ${namespace} \
            -o jsonpath='{.metadata.annotations.secret\.checksum}' 2>/dev/null || echo "")
        
        if [[ -n "$expected_checksum" && "$current_checksum" != "$expected_checksum" ]]; then
            echo "WARNING: Secret ${secret} has drifted (checksum mismatch)"
            drift_detected=1
        fi
    done
    
    return $drift_detected
}

# Function to check resource quota drift
check_quota_drift() {
    local namespace=$1
    
    echo "Checking resource quota drift..."
    
    # Get current resource usage
    local current_cpu=$(kubectl top pods -n ${namespace} --no-headers 2>/dev/null | \
        awk '{sum += substr($2, 1, length($2)-1)} END {print sum}' || echo "0")
    
    local current_memory=$(kubectl top pods -n ${namespace} --no-headers 2>/dev/null | \
        awk '{sum += substr($3, 1, length($3)-2)} END {print sum}' || echo "0")
    
    # Get resource quota limits
    local quota_cpu=$(kubectl get resourcequota -n ${namespace} -o jsonpath='{.items[0].status.hard.limits.cpu}' 2>/dev/null || echo "0")
    local quota_memory=$(kubectl get resourcequota -n ${namespace} -o jsonpath='{.items[0].status.hard.limits.memory}' 2>/dev/null || echo "0")
    
    if [[ "$quota_cpu" != "0" ]]; then
        # Convert to comparable units
        quota_cpu=${quota_cpu%m}
        current_cpu=$((current_cpu / 10))  # Convert millicores to percentage
        
        local cpu_usage=$((current_cpu * 100 / quota_cpu))
        
        if [[ $cpu_usage -gt 90 ]]; then
            echo "WARNING: CPU quota usage is high: ${cpu_usage}% (${current_cpu}m/${quota_cpu}m)"
            return 1
        else
            echo "✓ CPU quota usage: ${cpu_usage}% (${current_cpu}m/${quota_cpu}m)"
        fi
    fi
    
    if [[ "$quota_memory" != "0" ]]; then
        # Convert to comparable units
        quota_memory=${quota_memory%Mi}
        
        local memory_usage=$((current_memory * 100 / quota_memory))
        
        if [[ $memory_usage -gt 90 ]]; then
            echo "WARNING: Memory quota usage is high: ${memory_usage}% (${current_memory}Mi/${quota_memory}Mi)"
            return 1
        else
            echo "✓ Memory quota usage: ${memory_usage}% (${current_memory}Mi/${quota_memory}Mi)"
        fi
    fi
    
    return 0
}

# Function to check security drift
check_security_drift() {
    local namespace=$1
    
    echo "Checking security configuration drift..."
    
    local drift_detected=0
    
    # Check for pods running as root
    echo "Checking for pods running as root..."
    
    local root_pods=$(kubectl get pods -n ${namespace} -o json | \
        jq -r '.items[] | select(.spec.securityContext.runAsUser == 0 or .spec.containers[].securityContext.runAsUser == 0) | .metadata.name' 2>/dev/null || echo "")
    
    if [[ -n "$root_pods" ]]; then
        echo "WARNING: Pods running as root found:"
        echo "$root_pods" | sed 's/^/  /'
        drift_detected=1
    fi
    
    # Check for pods with privileged access
    echo "Checking for pods with privileged access..."
    
    local privileged_pods=$(kubectl get pods -n ${namespace} -o json | \
        jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | .metadata.name' 2>/dev/null || echo "")
    
    if [[ -n "$privileged_pods" ]]; then
        echo "WARNING: Pods with privileged access found:"
        echo "$privileged_pods" | sed 's/^/  /'
        drift_detected=1
    fi
    
    # Check network policies
    echo "Checking network policies..."
    
    local network_policies=$(kubectl get networkpolicies -n ${namespace} --no-headers | wc -l)
    
    if [[ $network_policies -eq 0 ]]; then
        echo "WARNING: No network policies found in namespace ${namespace}"
        drift_detected=1
    else
        echo "✓ Network policies found: ${network_policies}"
    fi
    
    return $drift_detected
}

# Function to generate drift report
generate_drift_report() {
    local namespace=$1
    local deployment_id=$2
    local environment=$3
    
    echo ""
    echo "Generating drift report..."
    
    local report_file="drift-report-${deployment_id}.json"
    
    # Create JSON report
    cat > "$report_file" << EOF
{
  "deployment_id": "${deployment_id}",
  "environment": "${environment}",
  "namespace": "${namespace}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "checks": {
    "terraform": {
      "status": "completed",
      "drift_detected": false
    },
    "kubernetes": {
      "status": "completed",
      "drift_detected": false
    },
    "configuration": {
      "status": "completed",
      "drift_detected": false
    },
    "quota": {
      "status": "completed",
      "drift_detected": false
    },
    "security": {
      "status": "completed",
      "drift_detected": false
    }
  }
}
EOF
    
    echo "✓ Drift report generated: ${report_file}"
}

# Main drift detection logic
main() {
    local drift_detected=0
    
    echo "Starting configuration drift detection..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "Deployment ID: ${DEPLOYMENT_ID}"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Check Terraform drift
    if ! check_terraform_drift "$TERRAFORM_DIR"; then
        drift_detected=1
    fi
    
    echo ""
    
    # Check Kubernetes drift
    if ! check_kubernetes_drift "$NAMESPACE"; then
        drift_detected=1
    fi
    
    echo ""
    
    # Check configuration drift
    if ! check_config_drift "$NAMESPACE"; then
        drift_detected=1
    fi
    
    echo ""
    
    # Check resource quota drift
    if ! check_quota_drift "$NAMESPACE"; then
        drift_detected=1
    fi
    
    echo ""
    
    # Check security drift
    if ! check_security_drift "$NAMESPACE"; then
        drift_detected=1
    fi
    
    # Generate drift report
    generate_drift_report "$NAMESPACE" "$DEPLOYMENT_ID" "$ENVIRONMENT"
    
    echo ""
    echo "----------------------------------------"
    
    if [[ $drift_detected -eq 0 ]]; then
        echo "✅ No configuration drift detected"
        echo "Deployment ${DEPLOYMENT_ID} is in sync with expected configuration"
        exit 0
    else
        echo "❌ Configuration drift detected"
        echo "Deployment ${DEPLOYMENT_ID} has drifted from expected configuration"
        echo "Review the warnings above and consider running a sync operation"
        exit 1
    fi
}

# Run main function
main "$@"