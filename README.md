# Internal Developer Platform

Infrastructure as Code for provisioning EKS clusters with ArgoCD.

## Local Development

### Prerequisites

Make sure you're authenticated to AWS locally:

```bash
# If using AWS SSO
aws sso login --profile your-profile

# Or configure credentials
aws configure

# Test access
aws sts get-caller-identity
```

### Deploy Infrastructure Locally

To deploy from your local machine (instead of GitHub Actions):

```bash
cd infra/entry

# Initialize Terraform with S3 backend
terraform init \
  -backend-config="region=us-west-2" \
  -backend-config="bucket=terraform-state-alexidp-dev" \
  -backend-config="key=pr-0/state.tfstate"

# Apply with a local PR number
terraform apply -auto-approve -var="pr_number=0"
```

### Connect to EKS Cluster

After deployment:

```bash
# Get AWS credentials from SSO portal
# 1. Visit https://d-9267ef45c3.awsapps.com/start
# 2. Click "Access keys" and copy the credentials
# 3. Paste them into ~/.aws/credentials under the profile [935743309409_AdministratorAccess]

# Set AWS profile
export AWS_PROFILE=935743309409_AdministratorAccess

# Verify AWS access
aws sts get-caller-identity

# Update kubeconfig (replace <PR> with your PR number, or use 0 for local)
aws eks update-kubeconfig --region us-west-2 --name k8s-pr-<PR>

# Verify connection
kubectl get nodes
```

### Access ArgoCD Dashboard

```bash
# Update kubeconfig if not already done (replace <PR> with your PR number, or use 0 for local)
aws eks update-kubeconfig --region us-west-2 --name k8s-pr-<PR>

# Get the admin password (Option 1: via Terraform output)
cd infra/entry
terraform output -raw argocd_server_admin_password

# Get the admin password (Option 2: via kubectl - works after CI/CD deploys too)
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# Port-forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
```

Access at http://localhost:8080 and login with username `admin` and the password from above.

## CI/CD

GitHub Actions workflow automatically provisions infrastructure on pull requests using OIDC authentication (no long-lived credentials).

## Infrastructure Modules

- **VPC** - Network configuration with public/private subnets
- **EKS** - Kubernetes cluster
- **ArgoCD** - GitOps deployment tool

