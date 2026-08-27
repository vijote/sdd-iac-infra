# Quickstart Guide: Application Deployment Pipeline

**Purpose**: Get the Application Deployment Pipeline running quickly  
**Prerequisites**: Spec 003 and Spec 005 must be completed

## 1. Initial Setup

### 1.1 Repository Configuration
```bash
# Clone the repository
git clone git@github.com:your-org/sdd-infra.git
cd sdd-infra

# Switch to the pipeline branch
git checkout 006-application-deployment-pipeline
```

### 1.2 GitHub Secrets Configuration

**Note**: The application deployment pipeline automatically reuses all existing environment variables from the repository, including `STATE_BUCKET_NAME`, `AWS_BOOTSTRAP_ROLE`, `AWS_TERRAFORM_ROLE`, and others. These do not need to be reconfigured.

Navigate to **Repository Settings → Secrets and variables → Actions** and add:

#### Required Repository Variables (Already Configured)
| Variable Name | Description | Source |
|---------------|-------------|--------|
| `AWS_BOOTSTRAP_ROLE` | OIDC role for AWS access | Existing repository variable |
| `AWS_TERRAFORM_ROLE` | OIDC role for Terraform | Existing repository variable |
| `STATE_BUCKET_NAME` | S3 bucket for Terraform state | Existing repository variable |
| `AWS_ACCOUNT_ID` | AWS account ID | Existing repository variable |
| `AWS_TERRAFORM_ROLE_NAME` | Terraform role name | Existing repository variable |

#### Required Secrets
| Secret Name | Description | Example |
|-------------|-------------|---------|
| `KUBERNETES_CONFIG` | Base64 encoded kubeconfig | `(base64 ~/.kube/config)` |
| `MYSQL_ROOT_PASSWORD` | MySQL root password | `secure-password-123` |
| `JWT_SECRET` | JWT signing secret | `jwt-secret-key-456` |

#### Optional Secrets
| Secret Name | Description |
|-------------|-------------|
| `NOTIFICATION_WEBHOOK` | Slack/Teams webhook for notifications |
| `MONITORING_TOKEN` | Token for monitoring service integration |

### 1.3 Environment Setup
Create GitHub environments:

#### Development Environment
1. Go to **Settings → Environments**
2. Click **New environment**
3. Name: `dev`
4. Protection rules: None (auto-deploy enabled)
5. Secrets: Add `DEV_MYSQL_ROOT_PASSWORD`, `DEV_JWT_SECRET`

#### Production Environment
1. Create environment named `prod`
2. Protection rules:
   - Required reviewers: Add your team
   - Wait timer: 5 minutes
   - Restrict deployments to selected branches: `main`
3. Secrets: Add `PROD_MYSQL_ROOT_PASSWORD`, `PROD_JWT_SECRET`

## 2. Pipeline Configuration

### 2.1 Environment Configuration Files
Create environment-specific configurations:

```yaml
# .github/environments/dev.yml
environment: dev
auto_deploy: true
require_approval: false
resource_limits:
  cpu: "500m"
  memory: "1Gi"
  replicas: 1
```

```yaml
# .github/environments/prod.yml
environment: prod
auto_deploy: false
require_approval: true
approvers: ["admin-team"]
resource_limits:
  cpu: "1000m"
  memory: "2Gi"
  replicas: 2
```

### 2.2 Pipeline Configuration
```yaml
# .github/pipeline-config.yml
pipeline:
  name: "Application Deployment"
  version: "1.0"
  timeout_minutes: 30
  
applications:
  - name: "mysql"
    order: 1
    health_check_path: "/health"
    health_check_port: 3306
  - name: "backend"
    order: 2
    health_check_path: "/health"
    health_check_port: 3000
  - name: "frontend"
    order: 3
    health_check_path: "/health"
    health_check_port: 80
```

## 3. Running the Pipeline

### 3.1 Automatic Deployment (Development)
```bash
# Push to main branch - triggers automatic dev deployment
git add .
git commit -m "Add application deployment pipeline"
git push origin main
```

### 3.2 Manual Deployment (Any Environment)
1. Go to **Actions** tab in GitHub
2. Select **Application Deployment** workflow
3. Click **Run workflow**
4. Choose environment: `dev` or `prod`
5. Click **Run workflow**

### 3.3 Monitoring Deployment
- Watch the workflow progress in real-time
- Check logs for each step
- Receive notifications (if configured)
- View deployment status in the Actions tab

## 4. Validation

### 4.1 Check Deployment Status
```bash
# Check Kubernetes pods
kubectl get pods -n demo-apps

# Check services
kubectl get services -n demo-apps

# Check deployment status
kubectl get deployments -n demo-apps
```

### 4.2 Health Check Validation
```bash
# Test application health
curl http://frontend-service/health
curl http://backend-service/health

# Test database connectivity
kubectl exec -it deployment/backend -- node -e "
const mysql = require('mysql2');
const conn = mysql.createConnection({
  host: 'mysql-service',
  user: 'demo_user',
  password: process.env.DB_PASSWORD,
  database: 'demo_app'
});
conn.connect(err => {
  if (err) console.log('❌ DB connection failed');
  else console.log('✅ DB connection successful');
  conn.end();
});
"
```

### 4.3 Application Access
```bash
# Port forward to test locally
kubectl port-forward service/frontend-service 8080:80 -n demo-apps
kubectl port-forward service/backend-service 3000:3000 -n demo-apps

# Access applications
curl http://localhost:8080  # Frontend
curl http://localhost:3000/api/health  # Backend API
```

## 5. Rollback Procedures

### 5.1 Automatic Rollback
The pipeline automatically rolls back if:
- Health checks fail
- Deployment timeout occurs
- Resource limits are exceeded

### 5.2 Manual Rollback
1. Go to **Actions** tab
2. Find the successful deployment to rollback to
3. Click **Rollback** (if available) or:
4. Manually trigger workflow with rollback option

```bash
# Manual rollback via kubectl
kubectl rollout undo deployment/frontend -n demo-apps
kubectl rollout undo deployment/backend -n demo-apps
kubectl rollout undo deployment/mysql -n demo-apps
```

## 6. Troubleshooting

### Common Issues

#### Pipeline Fails at Terraform Init
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify S3 bucket exists
aws s3 ls s3://your-terraform-state-bucket
```

#### Deployment Fails at Health Check
```bash
# Check pod logs
kubectl logs -f deployment/backend -n demo-apps
kubectl logs -f deployment/frontend -n demo-apps
kubectl logs -f deployment/mysql -n demo-apps

# Check pod status
kubectl describe pod -l app=backend -n demo-apps
```

#### Secrets Not Available
```bash
# Verify secrets exist
kubectl get secrets -n demo-apps

# Check secret content
kubectl get secret mysql-secrets -n demo-apps -o yaml
```

### Debug Mode
Enable debug logging by adding to workflow:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## 7. Next Steps

### 7.1 Production Deployment
1. Ensure all dev tests pass
2. Update production configurations
3. Request production deployment approval
4. Monitor production deployment closely

### 7.2 Monitoring and Alerting
1. Set up monitoring dashboards
2. Configure alerting rules
3. Create notification channels
4. Document on-call procedures

### 7.3 Advanced Features
1. Implement blue-green deployments
2. Add canary release support
3. Integrate with APM tools
4. Add compliance scanning

## 8. Support

### Documentation
- [Pipeline Architecture](plan.md)
- [API Reference](data-model.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

### Getting Help
- Check workflow logs in GitHub Actions
- Review Kubernetes events: `kubectl get events -n demo-apps`
- Consult the troubleshooting guide
- Contact the infrastructure team

### Best Practices
1. Always test in dev first
2. Review changes before production deployment
3. Monitor resource usage
4. Keep secrets secure
5. Document any custom configurations

## 9. Cleanup

### Remove Test Deployments
```bash
# Delete test namespace
kubectl delete namespace demo-apps

# Clean up Terraform state
cd src/terraform/environments/dev
terraform destroy -auto-approve
```

### Reset Pipeline
1. Delete workflow runs in GitHub Actions
2. Clean up any manual resources
3. Reset environment configurations if needed