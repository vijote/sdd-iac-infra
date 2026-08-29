# Application Infrastructure Module

This Terraform module deploys foundational infrastructure components required for application workloads on a kubeadm Kubernetes cluster.

## Features

- **EBS CSI Driver**: Persistent storage using AWS EBS volumes
- **NGINX Ingress Controller**: External access and path-based routing
- **cert-manager**: Automatic SSL/TLS certificate management with Let's Encrypt
- **Storage Classes**: Pre-configured storage classes for different EBS volume types

## Architecture

The module deploys the following components:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Applications  │───▶│ NGINX Ingress    │───▶│  Internet       │
│                 │    │ Controller       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│ Persistent      │    │ cert-manager     │
│ Storage (EBS)   │    │ (SSL/TLS)        │
└─────────────────┘    └──────────────────┘
```

## Usage

```hcl
module "application_infrastructure" {
  source = "./modules/application-infrastructure"
  
  # Required inputs
  cluster_endpoint        = module.kubernetes.cluster_endpoint
  cluster_ca_certificate = module.kubernetes.cluster_ca_certificate
  cluster_name          = "sdd-k8s-cluster"
  cluster_oidc_issuer_url = module.kubernetes.cluster_oidc_issuer_url
  namespace             = "application-infrastructure"
  domain_name           = "apps.example.com"
  aws_region            = "us-east-1"
  
  # Optional inputs
  cert_manager_email = "admin@example.com"
  enable_monitoring = true
  
  tags = {
    Environment = "production"
    Team       = "platform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.0 |
| AWS Provider | >= 5.0 |
| Kubernetes Provider | >= 2.20 |
| Helm Provider | >= 2.9 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |
| kubernetes | ~> 2.20 |
| helm | ~> 2.9 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_endpoint | Kubernetes API server endpoint | `string` | n/a | yes |
| cluster_ca_certificate | Base64-encoded cluster CA certificate | `string` | n/a | yes |
| cluster_name | Name of the Kubernetes cluster | `string` | n/a | yes |
| cluster_oidc_issuer_url | OIDC issuer URL for the cluster | `string` | `""` | no |
| namespace | Namespace for infrastructure components | `string` | `"application-infrastructure"` | no |
| domain_name | Base domain for SSL certificates | `string` | n/a | yes |
| aws_region | AWS region | `string` | `"us-east-1"` | no |
| storage_classes | Storage class configurations | `map(object)` | `{}` | no |
| ingress_annotations | Additional annotations for ingress controller | `map(string)` | `{}` | no |
| cert_manager_email | Email for Let's Encrypt certificates | `string` | `null` | no |
| enable_monitoring | Enable basic monitoring endpoints | `bool` | `false` | no |
| resource_limits | Resource limits for components | `object` | `{}` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace where infrastructure components are deployed |
| ebs_csi_driver_iam_role_arn | IAM role ARN for EBS CSI driver |
| ebs_csi_driver_iam_role_name | IAM role name for EBS CSI driver |
| cert_manager_version | Version of cert-manager deployed |
| nginx_ingress_version | Version of NGINX Ingress controller deployed |
| nginx_ingress_service_name | Name of the NGINX Ingress controller service |
| nginx_ingress_namespace | Namespace where NGINX Ingress controller is deployed |
| storage_classes | Map of created storage classes |
| cluster_endpoint | Kubernetes cluster endpoint |
| cluster_name | Kubernetes cluster name |
| domain_name | Base domain for SSL certificates |

## Storage Classes

The module creates the following storage classes by default:

| Name | Type | Use Case |
|------|------|----------|
| gp3 | gp3 SSD | General purpose workloads (default) |
| io2 | io2 SSD | High-performance databases |
| sc1 | HDD | Low-cost, infrequently accessed data |
| st1 | HDD | Throughput-optimized big data |

## SSL/TLS Configuration

The module configures cert-manager with Let's Encrypt for automatic certificate management:

1. **ClusterIssuer**: Configured for production Let's Encrypt certificates
2. **Automatic Renewal**: Certificates are automatically renewed before expiration
3. **HTTP-01 Challenge**: Uses HTTP challenge for domain validation

## Monitoring

When `enable_monitoring = true`, the module enables:

- cert-manager Prometheus metrics
- NGINX Ingress controller metrics
- EBS CSI driver metrics

## Security Considerations

- **IAM Role**: EBS CSI driver uses IAM Role for Service Account (IRSA)
- **Least Privilege**: IAM policy includes only required EBS permissions
- **Network Policies**: All components deployed in dedicated namespace
- **RBAC**: Service accounts with minimal required permissions

## Dependencies

This module depends on:

- Kubernetes cluster (kubeadm-based)
- AWS IAM permissions for EBS and IAM role management
- Domain name configured for SSL certificates

## Examples

### Basic Usage

```hcl
module "app_infra" {
  source = "./modules/application-infrastructure"
  
  cluster_endpoint        = "https://k8s-api.example.com"
  cluster_ca_certificate = "LS0tLS1CRUdJTi..."
  cluster_name          = "production-cluster"
  namespace             = "app-infra"
  domain_name           = "apps.example.com"
  aws_region            = "us-east-1"
}
```

### With Custom Storage Classes

```hcl
module "app_infra" {
  source = "./modules/application-infrastructure"
  
  # ... other inputs ...
  
  storage_classes = {
    fast-ssd = {
      type               = "io2"
      iops               = 10000
      encrypted          = true
      reclaim_policy     = "Retain"
      allow_expansion    = true
    }
  }
}
```

### With Monitoring Enabled

```hcl
module "app_infra" {
  source = "./modules/application-infrastructure"
  
  # ... other inputs ...
  
  enable_monitoring = true
  cert_manager_email = "ops@example.com"
}
```

## Troubleshooting

### Common Issues

1. **EBS CSI Driver Fails to Start**
   - Verify IAM role permissions
   - Check OIDC provider configuration
   - Ensure cluster endpoint is accessible

2. **SSL Certificate Not Issued**
   - Verify domain DNS configuration
   - Check ingress controller is running
   - Ensure cert-manager email is configured

3. **Storage Classes Not Available**
   - Verify EBS CSI driver is running
   - Check AWS region and permissions
   - Validate storage class parameters

### Validation Commands

```bash
# Check namespace
kubectl get namespace application-infrastructure

# Check EBS CSI driver
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Check ingress controller
kubectl get pods -n application-infrastructure -l app.kubernetes.io/name=ingress-nginx

# Check cert-manager
kubectl get pods -n application-infrastructure -l app.kubernetes.io/name=cert-manager

# Check storage classes
kubectl get storageclass
```

## Contributing

1. Follow the existing code style
2. Update documentation for any changes
3. Test changes in a non-production environment
4. Update examples as needed

## License

This module is part of the SDD Infrastructure project.