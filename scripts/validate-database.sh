#!/bin/bash

# Database Connectivity Validation Script
# Usage: ./validate-database.sh <environment> <deployment_id>

set -euo pipefail

ENVIRONMENT=${1:-dev}
DEPLOYMENT_ID=${2:-$(date +%s)}
NAMESPACE="demo-apps"
DB_HOST="mysql"
DB_PORT="3306"
DB_USER="root"
DB_NAME="demo_app"

echo "Validating database connectivity for ${DEPLOYMENT_ID} in ${ENVIRONMENT}..."

# Function to get MySQL pod
get_mysql_pod() {
    local namespace=$1
    
    kubectl get pods \
        -l app=mysql \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

# Function to test database connectivity
test_database_connectivity() {
    local mysql_pod=$1
    local namespace=$2
    
    echo "Testing database connectivity..."
    
    # Test TCP connection
    if kubectl exec ${mysql_pod} -n ${namespace} -- \
        mysqladmin ping -h localhost --silent; then
        echo "✓ Database TCP connection successful"
        return 0
    else
        echo "ERROR: Database TCP connection failed"
        return 1
    fi
}

# Function to test database authentication
test_database_authentication() {
    local mysql_pod=$1
    local namespace=$2
    local db_user=${3:-root}
    
    echo "Testing database authentication..."
    
    # Test authentication
    if kubectl exec ${mysql_pod} -n ${namespace} -- \
        mysql -u ${db_user} -e "SELECT 1;" >/dev/null 2>&1; then
        echo "✓ Database authentication successful for user ${db_user}"
        return 0
    else
        echo "ERROR: Database authentication failed for user ${db_user}"
        return 1
    fi
}

# Function to test database operations
test_database_operations() {
    local mysql_pod=$1
    local namespace=$2
    local db_name=${3:-demo_app}
    
    echo "Testing database operations..."
    
    # Test database exists
    if kubectl exec ${mysql_pod} -n ${namespace} -- \
        mysql -e "USE ${db_name}; SELECT 1;" >/dev/null 2>&1; then
        echo "✓ Database ${db_name} is accessible"
    else
        echo "WARNING: Database ${db_name} not found or not accessible"
        return 0
    fi
    
    # Test table operations
    local tables=$(kubectl exec ${mysql_pod} -n ${namespace} -- \
        mysql -e "USE ${db_name}; SHOW TABLES;" 2>/dev/null | grep -v "Tables_in" || echo "")
    
    if [[ -n "$tables" ]]; then
        echo "✓ Database contains tables: ${tables}"
    else
        echo "WARNING: Database ${db_name} contains no tables"
    fi
    
    return 0
}

# Function to test database performance
test_database_performance() {
    local mysql_pod=$1
    local namespace=$2
    
    echo "Testing database performance..."
    
    # Test query performance
    local start_time=$(date +%s)
    
    if kubectl exec ${mysql_pod} -n ${namespace} -- \
        mysql -e "SELECT SLEEP(0.1);" >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $duration -le 2 ]]; then
            echo "✓ Database query performance acceptable (${duration}s)"
            return 0
        else
            echo "WARNING: Database query performance slow (${duration}s)"
            return 1
        fi
    else
        echo "ERROR: Database query performance test failed"
        return 1
    fi
}

# Function to check database replication
check_database_replication() {
    local mysql_pod=$1
    local namespace=$2
    
    echo "Checking database replication status..."
    
    # Check if replication is configured
    local replication_status=$(kubectl exec ${mysql_pod} -n ${namespace} -- \
        mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null || echo "")
    
    if [[ -n "$replication_status" ]]; then
        local slave_io_running=$(echo "$replication_status" | grep "Slave_IO_Running:" | awk '{print $2}')
        local slave_sql_running=$(echo "$replication_status" | grep "Slave_SQL_Running:" | awk '{print $2}')
        
        if [[ "$slave_io_running" == "Yes" && "$slave_sql_running" == "Yes" ]]; then
            echo "✓ Database replication is running"
            return 0
        else
            echo "WARNING: Database replication may have issues"
            echo "  Slave_IO_Running: ${slave_io_running}"
            echo "  Slave_SQL_Running: ${slave_sql_running}"
            return 1
        fi
    else
        echo "INFO: Database replication not configured"
        return 0
    fi
}

# Function to check database backups
check_database_backups() {
    local mysql_pod=$1
    local namespace=$2
    
    echo "Checking database backup status..."
    
    # Check for recent backups
    local backup_files=$(kubectl exec ${mysql_pod} -n ${namespace} -- \
        ls -lt /var/lib/mysql/*.sql 2>/dev/null | head -5 || echo "")
    
    if [[ -n "$backup_files" ]]; then
        echo "✓ Recent database backups found:"
        echo "$backup_files" | sed 's/^/  /'
        return 0
    else
        echo "WARNING: No recent database backups found"
        return 1
    fi
}

# Function to test application database connectivity
test_application_database_connectivity() {
    local namespace=$1
    
    echo "Testing application database connectivity..."
    
    # Get backend pod
    local backend_pod=$(kubectl get pods \
        -l app=backend \
        -n ${namespace} \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$backend_pod" ]]; then
        echo "WARNING: Backend pod not found for application database connectivity test"
        return 0
    fi
    
    # Test connectivity from backend to database
    if kubectl exec ${backend_pod} -n ${namespace} -- \
        nc -z ${DB_HOST} ${DB_PORT}; then
        echo "✓ Backend can connect to database"
        return 0
    else
        echo "ERROR: Backend cannot connect to database"
        return 1
    fi
}

# Main database validation logic
main() {
    local validation_failed=0
    
    echo "Starting database validation..."
    echo "Environment: ${ENVIRONMENT}"
    echo "Namespace: ${NAMESPACE}"
    echo "Database: ${DB_HOST}:${DB_PORT}"
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
        echo "ERROR: Namespace ${NAMESPACE} does not exist"
        exit 1
    fi
    
    # Get MySQL pod
    local mysql_pod=$(get_mysql_pod "$NAMESPACE")
    
    if [[ -z "$mysql_pod" ]]; then
        echo "ERROR: MySQL pod not found in namespace ${NAMESPACE}"
        exit 1
    fi
    
    echo "MySQL pod: ${mysql_pod}"
    echo ""
    
    # Test database connectivity
    if ! test_database_connectivity "$mysql_pod" "$NAMESPACE"; then
        validation_failed=1
    fi
    
    # Test database authentication
    if ! test_database_authentication "$mysql_pod" "$NAMESPACE" "$DB_USER"; then
        validation_failed=1
    fi
    
    # Test database operations
    if ! test_database_operations "$mysql_pod" "$NAMESPACE" "$DB_NAME"; then
        validation_failed=1
    fi
    
    # Test database performance
    if ! test_database_performance "$mysql_pod" "$NAMESPACE"; then
        validation_failed=1
    fi
    
    # Check database replication
    if ! check_database_replication "$mysql_pod" "$NAMESPACE"; then
        validation_failed=1
    fi
    
    # Check database backups
    if ! check_database_backups "$mysql_pod" "$NAMESPACE"; then
        validation_failed=1
    fi
    
    # Test application database connectivity
    if ! test_application_database_connectivity "$NAMESPACE"; then
        validation_failed=1
    fi
    
    echo ""
    echo "----------------------------------------"
    
    if [[ $validation_failed -eq 0 ]]; then
        echo "✅ Database validation completed successfully"
        echo "Database connectivity and operations are healthy for deployment ${DEPLOYMENT_ID}"
        exit 0
    else
        echo "❌ Database validation detected issues"
        echo "Database connectivity or operations have issues for deployment ${DEPLOYMENT_ID}"
        exit 1
    fi
}

# Run main function
main "$@"