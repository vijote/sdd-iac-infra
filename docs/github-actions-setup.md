# GitHub Actions Setup for Kubeadm Deployment

This document describes the required GitHub repository secrets and variables for deploying the application infrastructure to a kubeadm cluster using GitHub Actions.

## Repository Secrets

Navigate to **Settings → Secrets and variables → Actions** in your GitHub repository and add the following secrets:

### AWS Credentials
- `AWS_ACCESS_KEY_ID`: AWS access key with permissions to manage infrastructure
- `AWS_SECRET_ACCESS_KEY`: AWS secret access key

### Optional: Kubeconfig
- `KUBECONFIG_CONTENT`: Base64-encoded kubeconfig file content (optional)
  - If not provided, the workflow assumes the kubeconfig exists at `~/.kube/config`
  - To encode: `base64 -i ~/.kube/config`

## Repository Variables

Add the following variables under **Settings → Secrets and variables → Actions → Variables**:

### AWS Configuration
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `AWS_BOOTSTRAP_ROLE`: IAM role ARN for bootstrap operations
- `AWS_TERRAFORM_ROLE`: IAM role ARN for Terraform operations
- `AWS_TERRAFORM_ROLE_NAME`: Name of the Terraform IAM role
- `STATE_BUCKET_NAME`: S3 bucket name for Terraform state storage

### Terraform Variables (Optional)
- `TF_VAR_kubeconfig_path`: Path to kubeconfig file (default: `~/.kube/config`)

## Required IAM Permissions

The AWS roles need the following permissions:

### Bootstrap Role
- S3: Create and manage state bucket
- IAM: Create and manage Terraform role
- EC2: Full access for kubeadm cluster management
- VPC: Full access for networking

### Terraform Role
- S3: Read/write access to state bucket
- EC2: Full access for instance management
- VPC: Full access for networking
- Route53: For DNS management (if using custom domains)
- ECR: For container registry access

## Kubeadm Prerequisites

1. **Kubernetes Cluster**: A running kubeadm cluster with:
   - AWS EBS CSI driver installed
   - Ingress controller (NGINX) installed
   - Proper networking configured

2. **Kubeconfig**: The kubeconfig file must be accessible to the GitHub Actions runner:
   - Either provide via `KUBECONFIG_CONTENT` secret
   - Or ensure it's available at the default path

3. **EC2 Instance Profile**: The kubeadm worker nodes must have an IAM instance profile with:
   - Permissions to access EBS volumes
   - Permissions to access other AWS services as needed

## Deployment Process

1. **Manual Trigger**: Go to Actions → Terraform Apply → Run workflow
2. **Select Environment**: Choose `dev` or `prod`
3. **Monitor**: Watch the deployment progress in the Actions tab

## Troubleshooting

### Common Issues

1. **Kubeconfig not found**:
   - Ensure `KUBECONFIG_CONTENT` secret is properly base64 encoded
   - Or verify the kubeconfig path is correct

2. **AWS permission errors**:
   - Check IAM role permissions
   - Ensure role chaining is properly configured

3. **Terraform state errors**:
   - Verify state bucket exists and is accessible
   - Check bucket permissions

4. **Kubernetes connection errors**:
   - Verify cluster is running
   - Check network connectivity from GitHub Actions runner
   - Ensure kubeconfig has valid credentials

### Debug Steps

1. Check the workflow logs for detailed error messages
2. Verify all secrets and variables are correctly set
3. Test locally with the same configuration
4. Check IAM role policies and trust relationships

## Security Considerations

1. **Secrets Management**:
   - Never commit secrets to the repository
   - Use GitHub's encrypted secrets
   - Rotate credentials regularly

2. **IAM Roles**:
   - Follow principle of least privilege
   - Use role chaining for better security
   - Regularly audit permissions

3. **Network Security**:
   - Use security groups to restrict access
   - Enable VPC flow logs
   - Use private subnets where possible

## Environment-Specific Notes

### Development Environment
- Uses `dev` configuration
- State stored in `sdd-terraform-state-dev` bucket
- Namespace: `application-infrastructure`

### Production Environment
- Uses `prod` configuration
- State stored in `sdd-terraform-state-prod` bucket
- Namespace: `application-infrastructure`
- Additional security controls recommended