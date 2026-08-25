# Infrastructure Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    VPC                               │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ Public Sub  │  │ Public Sub  │  │ Public Sub  │  │   │
│  │  │    10.0.1   │  │    10.0.2   │  │    10.0.3   │  │   │
│  │  │             │  │             │  │             │  │   │
│  │  │  Control    │  │  Worker 1   │  │  Worker 2   │  │   │
│  │  │  Plane      │  │             │  │             │  │   │
│  │  │  t3.small   │  │  t3.micro   │  │  t3.micro   │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  │                                                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ Private Sub │  │ Private Sub │  │ Private Sub │  │   │
│  │  │   10.0.11   │  │   10.0.12   │  │   10.0.13   │  │   │
│  │  │             │  │             │  │             │  │   │
│  │  │ (Optional)  │  │ (Optional)  │  │ (Optional)  │  │   │
│  │  │  Future     │  │  Future     │  │  Future     │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              S3 Bucket                              │   │
│  │        Terraform State Storage                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Kubernetes Cluster Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                Control Plane                         │   │
│  │                                                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ kube-apiserver│ │kube-controller│ │  etcd       │  │   │
│  │  │   :6443     │ │   manager    │ │  :2379-2380 │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  │                                                     │   │
│  │  ┌─────────────┐  ┌─────────────┐                   │   │
│  │  │  scheduler  │ │   cloud-     │                   │   │
│  │  │             │ │ controller   │                   │   │
│  │  └─────────────┘  └─────────────┘                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                              │                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                  Worker Nodes                       │   │
│  │                                                     │   │
│  │  ┌─────────────┐              ┌─────────────┐      │   │
│  │  │   Worker 1  │              │   Worker 2  │      │   │
│  │  │             │              │             │      │   │
│  │  │ ┌─────────┐ │              │ ┌─────────┐ │      │   │
│  │  │ │kubelet  │ │              │ │kubelet  │ │      │   │
│  │  │ │:10250   │ │              │ │:10250   │ │      │   │
│  │  │ └─────────┘ │              │ └─────────┘ │      │   │
│  │  │ ┌─────────┐ │              │ ┌─────────┐ │      │   │
│  │  │ │kube-    │ │              │ │kube-    │ │      │   │
│  │  │ │proxy    │ │              │ │proxy    │ │      │   │
│  │  │ └─────────┘ │              │ └─────────┘ │      │   │
│  │  │ ┌─────────┐ │              │ ┌─────────┐ │      │   │
│  │  │ │container│ │              │ │container│ │      │   │
│  │  │ │d        │ │              │ │d        │ │      │   │
│  │  │ └─────────┘ │              │ └─────────┘ │      │   │
│  │  └─────────────┘              └─────────────┘      │   │
│  └─────────────────────────────────────────────────────┘   │
│                              │                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Pod Network                          │   │
│  │                                                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │   Pod A     │  │   Pod B     │  │   Pod C     │  │   │
│  │  │ 10.244.1.2  │  │ 10.244.2.3  │  │ 10.244.1.4  │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  │       │                │                │           │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │            Flannel CNI                      │   │   │
│  │  │          (VXLAN Backend)                   │   │   │
│  │  │           UDP:4789                          │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Network Flow

```
Internet Request Flow:
┌─────────────┐    HTTPS    ┌─────────────┐    ┌─────────────┐
│   Client    │ ────────> │  Internet   │ ────────> │  AWS IGW    │
│             │            │             │            │             │
└─────────────┘            └─────────────┘            └─────────────┘
                                                          │
                                                          ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Service   │<───│   Ingress   │<───│   NodePort  │
│   (Pod)     │    │ Controller  │    │ Service    │
└─────────────┘    └─────────────┘    └─────────────┘
       │                                        │
       ▼                                        ▼
┌─────────────┐                          ┌─────────────┐
│   Pod A     │                          │   Pod B     │
│ 10.244.1.2  │                          │ 10.244.2.3  │
└─────────────┘                          └─────────────┘
       │                                        │
       └────────────────┬─────────────────────────┘
                        ▼
              ┌─────────────────┐
              │   Flannel CNI   │
              │   (VXLAN)       │
              └─────────────────┘
```

## Security Groups

```
Control Plane Security Group:
┌─────────────────────────────────────────┐
│ Inbound Rules:                          │
│ ├─ SSH (22) from 0.0.0.0/0             │
│ ├─ Kubernetes API (6443) from:         │
│ │  ├─ Control Plane SG                  │
│ │  ├─ Worker SG                         │
│ │  └─ Bastion (if configured)           │
│ ├─ etcd (2379-2380) from Control Plane  │
│ └─ Flannel VXLAN (4789) from Workers   │
│                                         │
│ Outbound Rules:                         │
│ ├─ All traffic to 0.0.0.0/0            │
└─────────────────────────────────────────┘

Worker Node Security Group:
┌─────────────────────────────────────────┐
│ Inbound Rules:                          │
│ ├─ SSH (22) from 0.0.0.0/0             │
│ ├─ NodePort (30000-32767) from:         │
│ │  ├─ Control Plane SG                  │
│ │  ├─ Worker SG                         │
│ │  └─ 0.0.0.0/0 (if needed)            │
│ └─ Flannel VXLAN (4789) from:           │
│    ├─ Control Plane SG                  │
│    └─ Worker SG                         │
│                                         │
│ Outbound Rules:                         │
│ ├─ All traffic to 0.0.0.0/0            │
└─────────────────────────────────────────┘
```

## Data Flow

### Cluster Bootstrap Process
```
1. Cloud-Init Execution:
   ┌─────────────┐    cloud-init    ┌─────────────┐
   │   AWS EC2   │ ──────────────> │   Instance  │
   │   Launch    │                 │   Boot      │
   └─────────────┘                 └─────────────┘
                                          │
                                          ▼
2. Package Installation:
   ┌─────────────┐    apt-get      ┌─────────────┐
   │   Ubuntu    │ ─────────────> │ Packages:   │
   │   Repos     │                 │ containerd  │
   │             │                 │ kubeadm     │
   └─────────────┘                 │ kubelet     │
                                  │ kubectl     │
                                  └─────────────┘
                                          │
                                          ▼
3. Kubernetes Setup:
   ┌─────────────┐   kubeadm init   ┌─────────────┐
   │ Control     │ ───────────────> │ Kubernetes  │
   │ Plane       │                  │ Cluster    │
   └─────────────┘                  └─────────────┘
                                          │
                                          ▼
4. Worker Join:
   ┌─────────────┐   join command   ┌─────────────┐
   │   Worker    │ ───────────────> │   Cluster   │
   │   Nodes     │                  │ Membership │
   └─────────────┘                  └─────────────┘
```

### Pod Communication
```
Pod-to-Pod Communication (Same Node):
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Pod A     │───>│  containerd │───>│   Pod B     │
│ 10.244.1.2  │    │   Bridge    │    │ 10.244.1.3  │
└─────────────┘    └─────────────┘    └─────────────┘

Pod-to-Pod Communication (Cross Node):
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Pod A     │───>│  Flannel    │───>│   Pod B     │
│ 10.244.1.2  │    │  VXLAN      │    │ 10.244.2.3  │
│ Node 1      │    │  Tunnel     │    │ Node 2      │
└─────────────┘    └─────────────┘    └─────────────┘
```

## Cost Breakdown (Monthly Estimates)

### Development Environment:
- Control Plane (t3.small): $0.0104/hr × 730 = $7.59
- 2 Workers (t3.micro): $0.0104/hr × 730 × 2 = $15.18
- EBS Volumes (20GB × 3): $0.08 × 60 = $4.80
- Data Transfer: ~$5.00
- **Total: ~$32.57/month**

### Production Environment:
- Control Plane (t3.medium): $0.0208/hr × 730 = $15.18
- 3 Workers (t3.small): $0.0104/hr × 730 × 3 = $22.77
- EBS Volumes (20GB × 4): $0.08 × 80 = $6.40
- Data Transfer: ~$10.00
- **Total: ~$54.35/month**

## Scaling Considerations

### Horizontal Scaling:
```
Add Worker Nodes:
┌─────────────┐
│   Current   │
│   Cluster   │
│             │
│ ┌─────────┐ │
│ │Control  │ │
│ │Plane    │ │
│ └─────────┘ │
│ ┌─────────┐ │
│ │Worker 1 │ │
│ └─────────┘ │
│ ┌─────────┐ │
│ │Worker 2 │ │
│ └─────────┘ │
└─────────────┘
        │
        ▼
┌─────────────┐
│   Scaled    │
│   Cluster   │
│             │
│ ┌─────────┐ │
│ │Control  │ │
│ │Plane    │ │
│ └─────────┘ │
│ ┌─────────┐ │
│ │Worker 1 │ │
│ └─────────┘ │
│ ┌─────────┐ │
│ │Worker 2 │ │
│ └─────────┘ │
│ ┌─────────┐ │
│ │Worker 3 │ │ ← New
│ └─────────┘ │
│ ┌─────────┐ │
│ │Worker 4 │ │ ← New
│ └─────────┘ │
└─────────────┘
```

### Vertical Scaling:
- Upgrade instance types in terraform.tfvars
- Consider t3.medium for workers under load
- Consider t3.large for control plane at scale

## Monitoring Points

### Key Metrics:
- Node CPU/Memory utilization
- Pod restart counts
- Network latency between nodes
- etcd performance (control plane)
- Flannel VXLAN packet drops

### Health Checks:
- Kubernetes API endpoint availability
- Node readiness status
- Pod network connectivity
- Service discovery functionality