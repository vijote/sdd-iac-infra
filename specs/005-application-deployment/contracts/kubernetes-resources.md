# Kubernetes Resource Contracts

**Date**: 2026-08-27  
**Feature**: Application Deployment Infrastructure

## Overview

This document defines the required Kubernetes resources and their interfaces for deploying the demo applications. All resources must follow these contracts to ensure proper integration.

## 1. Namespace Contract

### Required Labels
```yaml
labels:
  app.kubernetes.io/name: "demo-apps"
  app.kubernetes.io/component: "application-stack"
  app.kubernetes.io/version: "v1.0.0"
```

### Required Annotations
```yaml
annotations:
  description: "Demo applications namespace"
  managed-by: "terraform"
```

## 2. Deployment Contracts

### Frontend Deployment (SPA)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-frontend
  namespace: demo-apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-frontend
  template:
    metadata:
      labels:
        app: demo-frontend
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Backend Deployment (NodeJS)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-backend
  namespace: demo-apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-backend
  template:
    metadata:
      labels:
        app: demo-backend
        version: v1
    spec:
      containers:
      - name: nodejs
        image: node:18-alpine
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: db_host
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: db_password
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
```

### Database Deployment (MySQL)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-mysql
  namespace: demo-apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-mysql
  template:
    metadata:
      labels:
        app: demo-mysql
        version: v1
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
          name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secrets
              key: root_password
        - name: MYSQL_DATABASE
          valueFrom:
            configMapKeyRef:
              name: mysql-config
              key: database_name
        - name: MYSQL_USER
          valueFrom:
            configMapKeyRef:
              name: mysql-config
              key: username
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secrets
              key: user_password
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 300m
            memory: 512Mi
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        livenessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - mysql
            - -h
            - localhost
            - -e
            - "SELECT 1"
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-data-pvc
```

## 3. Service Contracts

### Frontend Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-frontend-service
  namespace: demo-apps
spec:
  type: ClusterIP
  selector:
    app: demo-frontend
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
```

### Backend Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-backend-service
  namespace: demo-apps
spec:
  type: ClusterIP
  selector:
    app: demo-backend
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: http
```

### Database Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-mysql-service
  namespace: demo-apps
spec:
  type: ClusterIP
  selector:
    app: demo-mysql
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
    name: mysql
```

## 4. Storage Contracts

### Persistent Volume Claim
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-pvc
  namespace: demo-apps
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 20Gi
```

## 5. Configuration Contracts

### ConfigMaps Structure
```yaml
# Backend ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: demo-apps
data:
  db_host: "demo-mysql-service"
  api_port: "3000"
  log_level: "info"

# MySQL ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: demo-apps
data:
  database_name: "demo_app"
  username: "demo_user"
```

### Secrets Structure
```yaml
# Backend Secrets
apiVersion: v1
kind: Secret
metadata:
  name: backend-secrets
  namespace: demo-apps
type: Opaque
data:
  db_password: <base64-encoded-password>

# MySQL Secrets
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secrets
  namespace: demo-apps
type: Opaque
data:
  root_password: <base64-encoded-password>
  user_password: <base64-encoded-password>
```

## 6. Ingress Contracts

### Ingress Resource
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-apps-ingress
  namespace: demo-apps
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: demo.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: demo-backend-service
            port:
              number: 3000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-frontend-service
            port:
              number: 80
```

## Validation Requirements

1. All resources must have proper labels for identification
2. Resource limits must not exceed t3.small capacity
3. Health checks must be configured for all deployments
4. Secrets must never contain plain-text passwords
5. All inter-service communication must use internal DNS
6. Persistent storage must be used for database data