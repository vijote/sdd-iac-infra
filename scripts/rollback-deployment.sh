#!/bin/bash

# Rollback Script
# Usage: ./rollback-deployment.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
BACKUP_DIR="/tmp/rollback-${DEPLOYMENT_ID}"
MAX_ROLLBACKS=5

echo "Rolling back deployment ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

# Function to create backup before rollback
create_backup() {
    local namespace=$1
    local backup_dir=$2
    
    echo "Creating backup of current deployment..."
    
    mkdir -p "$backup_dir"
    
    # Backup deployments
    kubectl get deployments -n ${namespace} -o yaml > "${backup_dir}/deployments.yaml"
    
    # Backup services
    kubectl get services -n ${namespace} -o yaml > "${backup_dir}/services.yaml"
    
    # Backup configmaps
    kubectl get configmaps -n ${namespace} -o yaml > "${backup_dir}/configmaps.yaml"
    
    # Backup secrets (metadata only)
    kubectl get secrets -n ${namespace} -o yaml > "${backup_dir}/secrets.yaml"
    
    # Record current replica counts
    kubectl get deployments -n ${namespace} -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.replicas}{"\n"}{end}' > "${backup_dir}/replica-counts.txt"
    
    echo "✓ Backup created at ${backup_dir}"
}

# Function to get previous deployment version
get_previous_version() {
    local app_name=$1
    local namespace=$2
    
    # Get revision history
    local revisions=$(kubectl rollout history deployment/${app_name} \
        -n ${namespace} \
        --revision=history 2>/dev/null || echo "")
    
    if [[ -z "$revisions" ]]; then
        echo "ERROR: No revision history found for ${app_name}"
        return 1
    fi
    
    # Get current revision
    local current_rev=$(kubectl get deployment ${app_name} \
        -n ${namespace} \
        -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' || echo "1")
    
    # Calculate previous revision
    local previous_rev=$((current_rev - 1))
    
    if [[ $previous_rev -lt 1 ]]; then
        echo "ERROR: No previous revision available for ${app_name}"
        return 1
    fi
    
    echo $previous_rev
}

# Function to rollback single application
rollback_application() {
    local app_name=$1
    local namespace=$2
    
    echo "Rolling back ${app_name}..."
    
    # Get previous revision
    local previous_rev=$(get_previous_version "$app_name" "$namespace")
    
    if [[ $? -ne 0 ]]; then
        echo "WARNING: Could not rollback ${app_name} - no previous version"
        return 1
    fi
    
    echo "Rolling back ${app_name} to revision ${previous_rev}..."
    
    # Perform rollback
    kubectl rollout undo deployment/${app_name} \
        -n ${namespace} \
        --to-revision=${previous_rev}
    
    # Wait for rollback to complete
    echo "Waiting for ${app_name} rollback to complete..."
    kubectl rollout status deployment/${app_name} \
        -n ${namespace} \
        --timeout=300s
    
    echo "✓ ${app_name} rolled back successfully"
    return 0
}

# Function to verify rollback health
verify_rollback_health() {
    local namespace=$1
    local timeout=60
    local interval=5
    
    echo "Verifying rollback health..."
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local all_healthy=true
        
        # Check all deployments
        local deployments=$(kubectl get deployments -n ${namespace} -o jsonpath='{.items[*].metadata.name}')
        
        for deployment in $deployments; do
            local ready_replicas=$(kubectl get deployment ${deployment} \
                -n ${namespace} \
                -o jsonpath='{.status.readyReplicas}' || echo "0")
            
            local replicas=$(kubectl get deployment ${deployment} \
                -n ${namespace} \
                -o jsonpath='{.spec.replicas}' || echo "1")
            
            if [[ "$ready_replicas" != "$replicas" ]]; then
                all_healthy=false
                break
            fi
        done
        
        if [[ "$all_healthy" == "true" ]]; then
            echo "✓ All deployments are healthy after rollback"
            return 0
        fi
        
        echo "Waiting for deployments to stabilize... (${elapsed}s elapsed)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo "WARNING: Rollback verification timed out"
    return 1
}

# Function to cleanup old rollback backups
cleanup_old_backups() {
    local max_backups=${1:-5}
    
    echo "Cleaning up old rollback backups (keeping last ${max_backups})..."
    
    # Find and remove old backup directories
    find /tmp -name "rollback-*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    
    # Keep only the most recent backups
    local backup_count=$(find /tmp -name "rollback-*" -type d | wc -l)
    
    if [[ $backup_count -gt $max_backups ]]; then
        find /tmp -name "rollback-*" -type d -printf '%T@ %p\n' | \
            sort -n | \
            head -n -$max_backups | \
            cut -d' ' -f2- | \
            xargs rm -rf 2>/dev/null || true
    fi
    
    echo "✓ Backup cleanup completed"
}

# Function to send rollback notification
send_rollback_notification() {
    local environment=$1
    local deployment_id=$2
    local status=$3
    
    echo "Sending rollback notification..."
    
    # Create notification message
    local message="Deployment rollback notification:
Environment: ${environment}
Deployment ID: ${deployment_id}
Status: ${status}
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    
    # Send to webhook if configured
    if [[ -n "${NOTIFICATION_WEBHOOK:-}" ]]; then
        curl -X POST "${NOTIFICATION_WEBHOOK}" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"${message}\"}" \
            2>/dev/null || echo "Failed to send webhook notification"
    fi
    
    # Log to console
    echo "$message"
}

# Main rollback logic
main() {
    echo "Starting rollback for deployment ${DEPLOYMENT_ID}..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Create backup before rollback
    create_backup "$NAMESPACE" "$BACKUP_DIR"
    
    # Get list of applications to rollback
    local apps=("backend" "frontend")
    local rollback_failed=0
    
    echo ""
    echo "Rolling back applications..."
    
    for app in "${apps[@]}"; do
        if kubectl get deployment ${app} -n ${NAMESPACE} >/dev/null 2>&1; then
            if ! rollback_application "$app" "$NAMESPACE"; then
                rollback_failed=1
            fi
        else
            echo "WARNING: Deployment ${app} not found, skipping"
        fi
    done
    
    echo ""
    echo "Verifying rollback health..."
    
    # Verify rollback health
    if ! verify_rollback_health "$NAMESPACE"; then
        rollback_failed=1
    fi
    
    # Cleanup old backups
    cleanup_old_backups $MAX_ROLLBACKS
    
    echo ""
    echo "----------------------------------------"
    
    if [[ $rollback_failed -eq 0 ]]; then
        echo "✅ Rollback completed successfully"
        send_rollback_notification "$ENVIRONMENT" "$DEPLOYMENT_ID" "SUCCESS"
        exit 0
    else
        echo "❌ Rollback completed with issues"
        send_rollback_notification "$ENVIRONMENT" "$DEPLOYMENT_ID" "PARTIAL"
        exit 1
    fi
}

# Handle script interruption
trap 'echo "Rollback interrupted"; exit 1' INT TERM

# Run main function
main "$@"