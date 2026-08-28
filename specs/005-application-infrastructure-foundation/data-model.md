# Data Model: Application Infrastructure Foundation

**Created**: 2026-08-28  
**Purpose**: Define data entities and relationships for infrastructure components  
**Status**: Complete

## Infrastructure Entities

### StorageClass

**Purpose**: Defines storage provisioner and parameters for dynamic volume provisioning

**Fields**:
- `name`: Storage class identifier (string)
- `provisioner`: CSI driver name (string, fixed: "ebs.csi.aws.com")
- `parameters`: Volume configuration (map)
  - `type`: EBS volume type (gp3, io2, io1, sc1, st1)
  - `iops`: IOPS performance (for io2, io1)
  - `throughput`: Throughput MB/s (for gp3)
  - `encrypted`: Encryption flag (boolean, default: true)
- `reclaimPolicy`: Volume reclaim policy (Retain/Delete)
- `allowVolumeExpansion`: Allow volume resizing (boolean)
- `volumeBindingMode`: When to bind volume (WaitFirst/Immediate)

**Validation Rules**:
- gp3: supports 3,000-16,000 IOPS, 125-1,000 MB/s throughput
- io2: supports 500-256,000 IOPS
- io1: supports 100-64,000 IOPS
- sc1/st1: fixed performance characteristics

**State Transitions**:
- Created → Available → InUse → Terminating

### PersistentVolumeClaim (PVC)

**Purpose**: User request for persistent storage

**Fields**:
- `name`: PVC identifier (string)
- `namespace`: Target namespace (string)
- `storageClassName`: Reference to StorageClass
- `accessModes`: ReadWriteOnce/ReadWriteMany/ReadOnlyMany
- `resources`: Storage request (CPU/Memory-like syntax)
- `volumeMode`: Filesystem/Block

**Validation Rules**:
- Size must be within EBS limits (1GiB - 16TiB)
- AccessModes must be compatible with volume type
- StorageClass must exist

**State Transitions**:
- Pending → Bound → Lost → Bound (if recovered)

### Ingress

**Purpose**: External access routing configuration

**Fields**:
- `name`: Ingress identifier (string)
- `namespace`: Target namespace (string)
- `rules`: Routing rules (array)
  - `host`: Hostname (string, optional)
  - `paths`: Path configurations (array)
    - `path`: URL path pattern (string)
    - `pathType`: Prefix/Exact/ImplementationSpecific
    - `backend`: Service reference
      - `service`: Service name
      - `port`: Service port
- `tls`: TLS configuration (array)
  - `hosts`: Certificate hostnames (array)
  - `secretName`: TLS certificate secret

**Validation Rules**:
- Paths must not conflict
- Service must exist
- Port must be valid
- TLS hosts must be reachable

**State Transitions**:
- Created → Address → Failed → Address

### Certificate

**Purpose**: SSL/TLS certificate managed by cert-manager

**Fields**:
- `name`: Certificate identifier (string)
- `namespace`: Target namespace (string)
- `dnsNames`: DNS names for certificate (array)
- `secretName`: Target secret for certificate
- `issuer`: Certificate issuer reference
- `duration`: Certificate validity period
- `renewBefore`: Renewal trigger time

**Validation Rules**:
- DNS names must be reachable
- Issuer must exist
- Duration must be within Let's Encrypt limits

**State Transitions**:
- Pending → Ready → Failed → Ready

### Service

**Purpose**: Network endpoint for pods

**Fields**:
- `name`: Service identifier (string)
- `namespace`: Target namespace (string)
- `type`: Service type (ClusterIP/NodePort/LoadBalancer)
- `selector`: Pod label selector (map)
- `ports`: Port configurations (array)
  - `name`: Port name
  - `port`: Service port
  - `targetPort`: Container port
  - `protocol`: TCP/UDP/SCTP

**Validation Rules**:
- Selector must match existing pods
- Ports must be within valid range
- Protocol must be supported

**State Transitions**:
- Pending → Running → Failed → Running

## Configuration Data

### Module Variables

**Input Variables**:
- `cluster_endpoint`: Kubernetes API endpoint
- `cluster_ca_certificate`: Cluster CA certificate
- `cluster_name`: Cluster identifier
- `namespace`: Target namespace for infrastructure
- `domain_name`: Base domain for SSL certificates
- `storage_classes`: Storage class configurations
- `ingress_annotations`: Ingress controller annotations

**Output Values**:
- `storage_class_names`: List of created storage class names
- `ingress_controller_service`: Ingress service endpoint
- `cert_manager_namespace`: cert-manager installation namespace
- `csi_driver_namespace`: EBS CSI driver namespace

### Provider Configuration

**Kubernetes Provider**:
- Host: cluster_endpoint
- Cluster CA certificate: cluster_ca_certificate
- Exec credentials: aws eks get-token (adapted for kubeadm)

**Helm Provider**:
- Kubernetes provider configuration inherited
- Repository configurations for charts

**AWS Provider**:
- Region: from AWS_REGION environment variable
- Assume role: from existing module outputs

## Relationships

```mermaid
erDiagram
    StorageClass ||--o{ PersistentVolumeClaim : provides
    PersistentVolumeClaim ||--|| Pod : mounts
    Ingress ||--o{ Service : routes_to
    Service ||--o{ Pod : selects
    Certificate ||--|| Ingress : secures
    Certificate ||--|| Secret : stores_in
    
    Module {
        +cluster_endpoint
        +cluster_ca_certificate
        +namespace
        +domain_name
    }
    
    Module ||--o{ StorageClass : creates
    Module ||--|| IngressController : deploys
    Module ||--|| CertManager : installs
    Module ||--|| CSI_DRIVER : configures
```

## State Management

### Terraform State

**Managed Resources**:
- Kubernetes resources (via kubernetes provider)
- Helm releases (via helm provider)
- AWS IAM roles (via aws provider)

**State Dependencies**:
- CSI driver IAM role must exist before driver installation
- Storage classes must exist before PVC creation
- cert-manager must exist before certificate issuance
- Ingress controller must exist before ingress creation

### Kubernetes State

**Resource Ordering**:
1. Namespace creation
2. IAM role and service account
3. Storage classes
4. CSI driver installation
5. cert-manager installation
6. Ingress controller installation
7. Validation resources

## Validation Rules

### Cross-Entity Constraints

- PVC size must be compatible with storage class type
- Ingress paths must not overlap
- Certificate DNS names must match ingress hosts
- Service ports must be unique within namespace
- Storage class names must be unique cluster-wide

### Performance Characteristics

- gp3 volumes: supports up to 16,000 IOPS, 1,000 MB/s throughput
- io2 volumes: supports up to 256,000 IOPS
- Ingress controller: resource limits configured for stability
- cert-manager: respects Let's Encrypt API rate limits

### Security Constraints

- All EBS volumes encrypted by default
- IAM roles follow least privilege
- Network policies restrict traffic
- Secrets stored in AWS Secrets Manager