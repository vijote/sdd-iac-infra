# Quickstart Guide: Application Deployment Infrastructure

**Date**: 2026-08-27  
**Feature**: Application Deployment Infrastructure

## Overview

This guide provides step-by-step instructions to deploy and validate the demo applications (SPA frontend, NodeJS backend, MySQL database) on the Kubernetes cluster.

## Prerequisites

1. **Completed Dependencies**:
   - Spec 003: Kubernetes Cluster Foundation deployed
   - Spec 006: Build-time Secrets Manager configured
   - Spec 007: Ingress Controller deployed

2. **Tools Required**:
   - kubectl configured to access the cluster
   - Terraform 1.0+ installed
   - AWS CLI configured with appropriate permissions

3. **AWS Resources**:
   - EKS cluster running
   - IAM role for Terraform execution
   - S3 bucket for Terraform state (if using remote state)

## Deployment Steps

### 1. Prepare Environment Variables

```bash
# Set environment
export TF_VAR_environment=dev  # or prod
export TF_VAR_region=us-east-1
export TF_VAR_cluster_name=<your-cluster-name>
```

### 2. Configure Secrets in AWS Secrets Manager

```bash
# Create database secrets
aws secretsmanager create-secret \
  --name "demo-apps/mysql-root-password" \
  --secret-string "<generate-strong-password>"

aws secretsmanager create-secret \
  --name "demo-apps/mysql-user-password" \
  --secret-string "<generate-strong-password>"

# Create backend secrets
aws secretsmanager create-secret \
  --name "demo-apps/backend-db-password" \
  --secret-string "<same-as-mysql-user-password>"
```

### 3. Initialize Terraform

```bash
cd src/terraform/modules/application-deployment

terraform init \
  -backend-config="bucket=<your-state-bucket>" \
  -backend-config="key=application-deployment/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

### 4. Review and Apply Terraform Plan

```bash
# Review the plan
terraform plan \
  -var-file="../../environments/${TF_VAR_environment}/terraform.tfvars"

# Apply the infrastructure
terraform apply \
  -var-file="../../environments/${TF_VAR_environment}/terraform.tfvars" \
  -auto-approve
```

### 5. Verify Namespace Creation

```bash
kubectl get namespace demo-apps
```

Expected output:
```
NAME        STATUS   AGE
demo-apps   Active   1m
```

### 6. Verify ConfigMaps and Secrets

```bash
# Check ConfigMaps
kubectl get configmaps -n demo-apps

# Check Secrets (should show synced from AWS)
kubectl get secrets -n demo-apps
```

### 7. Verify Deployments

```bash
# Check all deployments
kubectl get deployments -n demo-apps

# Expected output:
# NAME             READY   UP-TO-DATE   AVAILABLE   AGE
# demo-frontend    2/2     2            2           2m
# demo-backend     2/2     2            2           2m
# demo-mysql       1/1     1            1           2m
```

### 8. Verify Services

```bash
kubectl get services -n demo-apps
```

Expected output:
```
NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
demo-frontend-service    ClusterIP   10.100.200.50   <none>        80/TCP     3m
demo-backend-service     ClusterIP   10.100.200.51   <none>        3000/TCP   3m
demo-mysql-service       ClusterIP   10.100.200.52   <none>        3306/TCP   3m
```

### 9. Verify Pods are Running

```bash
kubectl get pods -n demo-apps
```

Expected output:
```
NAME                                 READY   STATUS    RESTARTS   AGE
demo-frontend-xxxx-yyyy               1/1     Running   0          3m
demo-frontend-xxxx-zzzz               1/1     Running   0          3m
demo-backend-xxxx-yyyy                1/1     Running   0          3m
demo-backend-xxxx-zzzz                1/1     Running   0          3m
demo-mysql-xxxx-yyyy                  1/1     Running   0          3m
```

### 10. Verify Persistent Storage

```bash
kubectl get pvc -n demo-apps
```

Expected output:
```
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES
mysql-data-pvc   Bound    pvc-xxxx-yyyy-zzzz                        20Gi       RWO
```

## Validation Tests

### Test 1: Frontend Health Check

```bash
kubectl port-forward -n demo-apps svc/demo-frontend-service 8080:80

# In another terminal
curl http://localhost:8080/health
```

Expected response: `OK`

### Test 2: Backend Health Check

```bash
kubectl port-forward -n demo-apps svc/demo-backend-service 3000:3000

# In another terminal
curl http://localhost:3000/health
```

Expected response: `{"status": "healthy", "database": "connected"}`

### Test 3: Database Connectivity

```bash
# Exec into backend pod
kubectl exec -it -n demo-apps deployment/demo-backend -- sh

# Test database connection
mysql -h demo-mysql-service -u demo_user -p demo_app
# Enter password when prompted

# Run a simple query
SHOW TABLES;
EXIT
```

### Test 4: Ingress Configuration

```bash
# Get the load balancer URL
kubectl get ingress -n demo-apps

# Test via curl (replace with actual URL)
curl http://<load-balancer-url>/health
curl http://<load-balancer-url>/api/health
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**
   ```bash
   kubectl describe pod <pod-name> -n demo-apps
   # Check for insufficient resources or taints
   ```

2. **Database connection failed**
   ```bash
   # Check secrets are synced
   kubectl get secret backend-secrets -n demo-apps -o yaml
   
   # Check database pod logs
   kubectl logs deployment/demo-mysql -n demo-apps
   ```

3. **Ingress not working**
   ```bash
   # Check ingress controller logs
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   
   # Check ingress resource
   kubectl describe ingress demo-apps-ingress -n demo-apps
   ```

### Cleanup Commands

```bash
# Remove all resources
terraform destroy \
  -var-file="../../environments/${TF_VAR_environment}/terraform.tfvars" \
  -auto-approve

# Delete AWS secrets
aws secretsmanager delete-secret \
  --secret-id "demo-apps/mysql-root-password" \
  --force-recover-without-period

aws secretsmanager delete-secret \
  --secret-id "demo-apps/mysql-user-password" \
  --force-recover-without-period

aws secretsmanager delete-secret \
  --secret-id "demo-apps/backend-db-password" \
  --force-recover-without-period
```


## Success Criteria

✅ All three applications are deployed and running  
✅ Frontend serves static content via nginx  
✅ Backend API is accessible and connects to MySQL  
✅ Database persists data across pod restarts  
✅ Health checks are working for all services  
✅ Ingress routes traffic correctly  
✅ Configuration is managed via ConfigMaps and Secrets  
✅ Total resource usage stays within cluster capacity