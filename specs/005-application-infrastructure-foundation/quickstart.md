# Quickstart Guide: Application Infrastructure Foundation

**Created**: 2026-08-28  
**Purpose**: Quick validation guide for infrastructure deployment  
**Estimated Time**: 30-45 minutes

## Prerequisites

### Tools Required

- Terraform 1.0+ installed locally
- kubectl configured for target cluster
- AWS CLI configured with appropriate permissions
- Helm 3.x installed locally
- Domain name with DNS access

### AWS Permissions

Required AWS permissions:
- EC2:FullAccess (for EBS volume management)
- IAM:CreateRole, IAM:AttachRolePolicy (for CSI driver IAM role)
- Route53:ChangeResourceRecordSets (if using Route53 for DNS)

### Cluster Access

- kubectl must be able to connect to the cluster
- User must have cluster-admin permissions
- Cluster must be running kubernetes 1.24+

## Deployment Steps

### 1. Prepare Environment

```bash
# Set environment variables
export TF_VAR_cluster_endpoint=$(terraform output -raw cluster_endpoint)
export TF_VAR_cluster_ca_certificate=$(terraform output -raw cluster_ca_certificate)
export TF_VAR_cluster_name="sdd-k8s-cluster"
export TF_VAR_namespace="application-infrastructure"
export TF_VAR_domain_name="apps.example.com"
export TF_VAR_cert_manager_email="admin@example.com"
export TF_VAR_aws_region="us-east-1"
```

### 2. Initialize Terraform

```bash
cd src/terraform/environments/dev

# Initialize modules
terraform init

# Plan the deployment
terraform plan -target=module.application_infrastructure
```

### 3. Deploy Infrastructure

```bash
# Apply the infrastructure
terraform apply -target=module.application_infrastructure

# Confirm when prompted
```

Expected output should show creation of:
- 1 namespace
- 4 storage classes
- 1 IAM role and policy
- 3 Helm releases (CSI driver, cert-manager, ingress controller)

## Validation Steps

### 1. Verify Storage Classes

```bash
# List storage classes
kubectl get storageclass

# Expected output:
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp3 (default)   ebs.csi.aws.com        Retain          WaitForFirstConsumer   true                   2m
io2             ebs.csi.aws.com        Retain          WaitForFirstConsumer   true                   2m
sc1             ebs.csi.aws.com        Retain          WaitForFirstConsumer   false                  2m
st1             ebs.csi.aws.com        Retain          WaitForFirstConsumer   false                  2m
```

### 2. Verify CSI Driver

```bash
# Check CSI driver pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Expected output: 3 pods running (controller, node daemonset)
NAME                                   READY   STATUS    RESTARTS   AGE
ebs-csi-controller-xxxxxxxxxxxxx       3/3     Running   0          3m
ebs-csi-node-xxxxxxxx                  2/2     Running   0          3m
ebs-csi-node-yyyyyyyy                  2/2     Running   0          3m
```

### 3. Verify cert-manager

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Expected output:
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-xxxxxxxxxxxxx                 1/1     Running   0          2m
cert-manager-cainjector-xxxxxxxxxxxxx      1/1     Running   0          2m
cert-manager-webhook-xxxxxxxxxxxxx         1/1     Running   0          2m
```

### 4. Verify Ingress Controller

```bash
# Check ingress controller pods
kubectl get pods -n application-infrastructure -l app.kubernetes.io/name=ingress-nginx

# Expected output:
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-xxxxxxxxxxxxx      1/1     Running   0          1m
ingress-nginx-controller-yyyyyyyyyyy       1/1     Running   0          1m
```

### 5. Test Storage Functionality

Create a test PVC:

```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: application-infrastructure
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 5Gi
EOF
```

Verify PVC status:

```bash
kubectl get pvc test-pvc -n application-infrastructure

# Expected output:
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-pvc  Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   5Gi        RWO            gp3            30s
```

### 6. Test Ingress and SSL

Create a test deployment and service:

```bash
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: application-infrastructure
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  namespace: application-infrastructure
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
EOF
```

Create an ingress with SSL:

```bash
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress
  namespace: application-infrastructure
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - test.${TF_VAR_domain_name}
    secretName: test-app-tls
  rules:
  - host: test.${TF_VAR_domain_name}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app-service
            port:
              number: 80
EOF
```

Wait for certificate issuance:

```bash
# Check certificate status
kubectl get certificate test-app-tls -n application-infrastructure

# Expected output (may take 2-5 minutes):
NAME          READY   SECRET        ISSuer          STATUS
test-app-tls   True    test-app-tls   letsencrypt-prod   Ready
```

### 7. Test External Access

Get the ingress controller IP:

```bash
# Get the worker node IP (since we're using NodePort internally)
kubectl get nodes -o wide

# Or if using LoadBalancer service type
kubectl get svc -n application-infrastructure ingress-nginx-controller
```

Test the application:

```bash
# Update DNS record for test.${TF_VAR_domain_name} to point to the ingress
# Then test with curl:
curl -k https://test.${TF_VAR_domain_name}

# Expected output: NGINX welcome page
```

## Cleanup Test Resources

```bash
# Remove test resources
kubectl delete -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress
  namespace: application-infrastructure
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  namespace: application-infrastructure
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: application-infrastructure
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: application-infrastructure
EOF
```

## Troubleshooting

### Common Issues

1. **CSI Driver Not Working**
   ```bash
   # Check driver logs
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
   
   # Check IAM role
   aws iam get-role --role-name ${TF_VAR_cluster_name}-ebs-csi-driver
   ```

2. **Certificate Not Issuing**
   ```bash
   # Check cert-manager logs
   kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
   
   # Check certificate details
   kubectl describe certificate test-app-tls -n application-infrastructure
   ```

3. **Ingress Not Accessible**
   ```bash
   # Check ingress controller logs
   kubectl logs -n application-infrastructure -l app.kubernetes.io/name=ingress-nginx
   
   # Check service endpoints
   kubectl get svc -n application-infrastructure
   ```

### Debug Commands

```bash
# Check all infrastructure components
kubectl get all -n application-infrastructure
kubectl get all -n cert-manager
kubectl get storageclass

# Check events
kubectl get events -n application-infrastructure --sort-by='.lastTimestamp'
kubectl get events -n cert-manager --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -n application-infrastructure
```

## Resource Requirements

For testing and validation:

- EBS volumes: Test volumes (5Gi gp3) for storage validation
- Data transfer: Minimal for testing
- Compute resources: Standard instance requirements for infrastructure components

## Next Steps

Once validation is complete:

1. The infrastructure is ready for application deployment
2. Use the created storage classes for application PVCs
3. Configure ingress resources for application external access
4. Set up monitoring and logging as needed
5. Proceed to application workload deployment (spec 006)

## Support

For issues:

1. Check the troubleshooting section above
2. Review the module documentation in [contracts/module-interface.md](contracts/module-interface.md)
3. Consult the research findings in [research.md](research.md)
4. Check the main specification in [spec.md](spec.md)