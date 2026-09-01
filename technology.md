# 🛠️ Technologies Used in `sdd-iac-infra`

## ☁️ Cloud Provider

| Technology | Role |
|------------|------|
| **AWS** | Primary cloud — EC2, VPC, S3, EBS, IAM, Secrets Manager, Route53 |

---

## 🏗️ Infrastructure as Code

| Technology | Role |
|------------|------|
| **Terraform ≥ 1.5** | Source of truth for all infra (VPC, EC2, K8s resources) |
| **AWS CloudFormation** | One-time IAM role provisioning (to avoid circular dependencies with Terraform) |

---

## ☸️ Kubernetes

| Technology | Role |
|------------|------|
| **kubeadm** | Cluster bootstrap — initializes control plane and joins workers |
| **Flannel CNI** | Pod networking (VXLAN backend) |
| **EBS CSI Driver** | Persistent volume provisioning from AWS EBS |
| **NGINX Ingress Controller** | External HTTP/HTTPS routing into the cluster |
| **cert-manager** | Automatic SSL/TLS certificate management (Let''s Encrypt) |

---

## 🔒 Security & Authentication

| Technology | Role |
|------------|------|
| **GitHub OIDC** | Keyless AWS authentication for GitHub Actions (no static credentials) |
| **AWS IAM** | Least-privilege roles for Terraform and cluster operations |
| **AWS Secrets Manager** | Application secret storage (MySQL passwords, JWT secrets) |
| **Let''s Encrypt** | Free SSL/TLS certificates via cert-manager HTTP-01 challenge |

---

## ⚙️ CI/CD

| Technology | Role |
|------------|------|
| **GitHub Actions** | All CI/CD pipelines (plan, apply, destroy, unlock state) |

---

## 🖥️ Compute

| Technology | Role |
|------------|------|
| **AWS EC2** | Kubernetes nodes — `t3.small` (control plane), `t3.micro` (workers) |
| **cloud-init / YAML** | Automated node bootstrapping scripts |
| **Ubuntu** | OS on all EC2 nodes |

---

## 📦 Application Stack (workloads being deployed)

| Technology | Role |
|------------|------|
| **Docker** | Container image runtime |
| **SPA Frontend** | Single-page app served at `/` |
| **Node.js** | Backend API served at `/api/*` |
| **MySQL** | Relational database (stateful, backed by EBS PVC) |

---

## 🧪 Testing

| Technology | Role |
|------------|------|
| **Go** | Language for local validation tests (`go test`) |
| **Bash** | 17 operational scripts (deploy, validate, rollback, monitor, etc.) |

---

## 📦 Package / Config Management

| Technology | Role |
|------------|------|
| **Helm** | Kubernetes package manager (used in `application-infrastructure` module for ingress + cert-manager) |
| **TFLint** | Terraform linting (`.tflint.hcl` configured at root) |

---

## 🗄️ State Management

| Technology | Role |
|------------|------|
| **AWS S3** | Remote Terraform state storage with native S3 object locking (no DynamoDB) |
