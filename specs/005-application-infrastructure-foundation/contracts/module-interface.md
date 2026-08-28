# Module Interface Contract: Application Infrastructure

**Created**: 2026-08-28  
**Purpose**: Define the interface contract for application-infrastructure module  
**Version**: 1.0

## Module Overview

The `application-infrastructure` module provides foundational Kubernetes infrastructure components required for application deployment. It consumes outputs from the `kubernetes` module and provisions storage, ingress, and certificate management capabilities.

## Input Variables

### Required Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `cluster_endpoint` | string | Kubernetes API server endpoint | `"https://k8s-api.example.com"` |
| `cluster_ca_certificate` | string | Base64-encoded cluster CA certificate | `"LS0tLS1CRUdJTi..."` |
| `cluster_name` | string | Name of the Kubernetes cluster | `"sdd-k8s-cluster"` |
| `namespace` | string | Namespace for infrastructure components | `"application-infrastructure"` |
| `domain_name` | string | Base domain for SSL certificates | `"apps.example.com"` |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `storage_classes` | map(object) | `{}` | Storage class configurations |
| `ingress_annotations` | map(string) | `{}` | Additional annotations for ingress controller |
| `cert_manager_email` | string | `null` | Email for Let's Encrypt certificates |
| `enable_monitoring` | bool | `false` | Enable basic monitoring endpoints |
| `resource_limits` | object | `{}` | Resource limits for components |

### Variable Objects

#### storage_classes Object

```hcl
storage_classes = {
  gp3 = {
    type = "gp3"
    iops = 3000
    throughput = 125
    encrypted = true
    reclaim_policy = "Retain"
    allow_expansion = true
  },
  io2 = {
    type = "io2"
    iops = 10000
    encrypted = true
    reclaim_policy = "Retain"
    allow_expansion = true
  }
}
```

#### resource_limits Object

```hcl
resource_limits = {
  ingress_controller = {
    cpu_request = "100m"
    cpu_limit = "500m"
    memory_request = "128Mi"
    memory_limit = "512Mi"
  },
  cert_manager = {
    cpu_request = "10m"
    cpu_limit = "100m"
    memory_request = "32Mi"
    memory_limit = "128Mi"
  },
  csi_driver = {
    cpu_request = "10m"
    cpu_limit = "100m"
    memory_request = "32Mi"
    memory_limit = "64Mi"
  }
}
```

## Output Values

| Output | Type | Description | Example |
|--------|------|-------------|---------|
| `storage_class_names` | list(string) | Names of created storage classes | `["gp3", "io2", "sc1", "st1"]` |
| `ingress_controller_service` | object | Ingress controller service details | `{name="ingress-nginx", namespace="application-infrastructure"}` |
| `cert_manager_namespace` | string | cert-manager installation namespace | `"cert-manager"` |
| `csi_driver_namespace` | string | EBS CSI driver namespace | `"kube-system"` |
| `namespace` | string | Created namespace name | `"application-infrastructure"` |
| `module_version` | string | Module version for tracking | `"1.0.0"` |

### Output Objects

#### ingress_controller_service Object

```hcl
ingress_controller_service = {
  name = "ingress-nginx-controller"
  namespace = "application-infrastructure"
  type = "ClusterIP"
  cluster_ip = "10.96.0.100"
  ports = [
    {
      name = "http"
      port = 80
      target_port = 80
    },
    {
      name = "https"
      port = 443
      target_port = 443
    }
  ]
}
```

## Provider Requirements

### Required Providers

```hcl
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source = "hashicorp/helm"
      version = "~> 2.10"
    }
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Provider Configuration

```hcl
provider "kubernetes" {
  host = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command = "aws"
    args = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command = "aws"
      args = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

## Dependencies

### Upstream Dependencies

The module requires the following outputs from the `kubernetes` module:

```hcl
cluster_endpoint = module.kubernetes.cluster_endpoint
cluster_ca_certificate = module.kubernetes.cluster_ca_certificate
cluster_name = module.kubernetes.cluster_name
aws_region = module.kubernetes.aws_region
```

### External Dependencies

- AWS CLI configured with appropriate permissions
- kubectl access to the target cluster
- Helm 3.x installed locally for Terraform provider

## Resource Naming Conventions

### Kubernetes Resources

- Namespace: `var.namespace`
- Storage Classes: `{key}` from storage_classes map
- Services: `{component}-{type}` (e.g., `ingress-nginx-controller`)
- ConfigMaps: `{component}-{purpose}` (e.g., `ingress-nginx-controller`)

### Helm Releases

- CSI Driver: `aws-ebs-csi-driver`
- cert-manager: `cert-manager`
- Ingress Controller: `ingress-nginx`

### AWS Resources

- IAM Role: `{var.cluster_name}-ebs-csi-driver`
- IAM Policy: `{var.cluster_name}-ebs-csi-driver-policy`

## Tagging Strategy

All AWS resources are tagged with:

```hcl
tags = {
  Project = "sdd-infra"
  Module = "application-infrastructure"
  Cluster = var.cluster_name
  ManagedBy = "terraform"
}
```

## Security Requirements

### IAM Permissions

The module creates an IAM role with the following minimum permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume",
        "ec2:DeleteVolume",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:DescribeVolumes",
        "ec2:DescribeInstances",
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot",
        "ec2:DescribeSnapshots"
      ],
      "Resource": "*"
    }
  ]
}
```

### Network Security

- All components deployed in dedicated namespace
- Network policies restrict inter-component traffic
- Ingress controller configured with security headers
- All EBS volumes encrypted by default

## Usage Example

```hcl
module "application_infrastructure" {
  source = "./modules/application-infrastructure"
  
  # Required inputs
  cluster_endpoint = module.kubernetes.cluster_endpoint
  cluster_ca_certificate = module.kubernetes.cluster_ca_certificate
  cluster_name = module.kubernetes.cluster_name
  namespace = "application-infrastructure"
  domain_name = "apps.example.com"
  
  # Optional inputs
  cert_manager_email = "admin@example.com"
  enable_monitoring = true
  
  storage_classes = {
    gp3 = {
      type = "gp3"
      iops = 3000
      throughput = 125
      encrypted = true
      reclaim_policy = "Retain"
      allow_expansion = true
    }
  }
}
```

## Version Compatibility

| Module Version | Terraform | Kubernetes | AWS Provider |
|---------------|-----------|-------------|--------------|
| 1.0.x | >= 1.0 | >= 1.24 | >= 5.0 |

## Testing Requirements

### Prerequisites

- Functional Kubernetes cluster
- AWS credentials with EBS permissions
- Domain name configured with DNS

### Validation Steps

1. Deploy module with example configuration
2. Verify storage classes are created
3. Test PVC creation and volume attachment
4. Deploy test service with ingress
5. Verify SSL certificate issuance
6. Test path-based routing
7. Validate resource limits

## Troubleshooting

### Common Issues

1. **CSI Driver Installation Failure**
   - Check IAM role permissions
   - Verify AWS credentials
   - Review driver logs

2. **Certificate Issuance Failure**
   - Verify domain DNS configuration
   - Check Let's Encrypt rate limits
   - Review cert-manager logs

3. **Ingress Controller Issues**
   - Check service endpoints
   - Verify RBAC permissions
   - Review ingress controller logs

### Debug Commands

```bash
# Check storage classes
kubectl get storageclass

# Check CSI driver
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Check cert-manager
kubectl get pods -n cert-manager
kubectl get certificate -A

# Check ingress controller
kubectl get pods -n application-infrastructure -l app.kubernetes.io/name=ingress-nginx
kubectl get ingress -A
```