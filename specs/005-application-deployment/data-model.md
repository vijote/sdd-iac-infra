# Data Model: Application Deployment Infrastructure

**Date**: 2026-08-27  
**Feature**: Application Deployment Infrastructure  
**Phase**: 1 - Design & Contracts

## Infrastructure Entities

### 1. Application Deployments

#### SPA Frontend
```yaml
Entity: FrontendDeployment
Fields:
  - name: string (e.g., "demo-frontend")
  - image: string (nginx-based SPA image)
  - replicas: integer (default: 2)
  - cpu_limit: string (e.g., "100m")
  - memory_limit: string (e.g., "128Mi")
  - health_endpoint: string ("/health")
Relationships:
  - BelongsTo: Namespace
  - ExposedBy: IngressRule
  - ConfiguredBy: ConfigMap
```

#### NodeJS Backend
```yaml
Entity: BackendDeployment
Fields:
  - name: string (e.g., "demo-backend")
  - image: string (NodeJS application image)
  - replicas: integer (default: 2)
  - cpu_limit: string (e.g., "200m")
  - memory_limit: string (e.g., "256Mi")
  - health_endpoint: string ("/health")
  - database_host: string (MySQL service name)
Relationships:
  - BelongsTo: Namespace
  - ExposedBy: IngressRule
  - ConnectsTo: DatabaseDeployment
  - ConfiguredBy: ConfigMap, Secret
```

#### MySQL Database
```yaml
Entity: DatabaseDeployment
Fields:
  - name: string (e.g., "demo-mysql")
  - image: string (MySQL 8.0)
  - cpu_limit: string (e.g., "300m")
  - memory_limit: string (e.g., "512Mi")
  - storage_size: string (e.g., "20Gi")
  - storage_class: string ("gp3")
  - database_name: string
  - username: string
Relationships:
  - BelongsTo: Namespace
  - Uses: PersistentVolumeClaim
  - ConfiguredBy: Secret
```

### 2. Storage Resources

#### Persistent Volume Claim
```yaml
Entity: PersistentVolumeClaim
Fields:
  - name: string (e.g., "mysql-data-pvc")
  - access_modes: array (["ReadWriteOnce"])
  - storage_size: string (e.g., "20Gi")
  - storage_class: string ("gp3")
Relationships:
  - BelongsTo: Namespace
  - BoundTo: PersistentVolume
```

### 3. Network Resources

#### Kubernetes Service
```yaml
Entity: Service
Fields:
  - name: string
  - type: string ("ClusterIP")
  - selector: map (app labels)
  - ports: array of port mappings
Relationships:
  - BelongsTo: Namespace
  - Selects: Deployment
```

#### Ingress Rule
```yaml
Entity: IngressRule
Fields:
  - host: string (domain name)
  - path: string (URL path)
  - path_type: string ("Prefix")
  - service_name: string
  - service_port: integer
Relationships:
  - BelongsTo: Ingress
  - RoutesTo: Service
```

### 4. Configuration Resources

#### ConfigMap
```yaml
Entity: ConfigMap
Fields:
  - name: string
  - data: map (key-value pairs)
Relationships:
  - BelongsTo: Namespace
  - ReferencedBy: Deployment
```

#### Secret
```yaml
Entity: Secret
Fields:
  - name: string
  - type: string ("Opaque" or "kubernetes.io/tls")
  - data: map (base64 encoded values)
Relationships:
  - BelongsTo: Namespace
  - ReferencedBy: Deployment
```

## State Transitions

### Deployment Lifecycle
1. **Pending** → **Running**: Pod starts and passes readiness probe
2. **Running** → **Failed**: Health check fails repeatedly
3. **Failed** → **Running**: Pod is restarted and passes health checks

### Storage Lifecycle
1. **Pending** → **Bound**: PVC is bound to PV
2. **Bound** → **Terminating**: Deployment is deleted
3. **Terminating** → **Deleted**: PVC is deleted

## Validation Rules

### Resource Constraints
- Total CPU requests ≤ 1800m (leaving 200m for system)
- Total memory requests ≤ 1800Mi (leaving 200Mi for system)
- Individual deployments must not exceed t3.small limits

### Security Rules
- All secrets must be stored in AWS Secrets Manager
- No plain-text passwords in ConfigMaps
- Database must use encrypted EBS volumes
- All inter-service communication within cluster only

### Availability Rules
- Frontend/Backend must have at least 2 replicas
- Database must have persistent storage
- All services must have health checks
- Failed pods must be automatically restarted

## Data Flow

User Request → Ingress Controller → [Path: /api/* → Backend → MySQL] OR [Path: /* → Frontend]

## Configuration Flow

AWS Secrets Manager → External Secrets Operator → Kubernetes Secrets → Application Containers