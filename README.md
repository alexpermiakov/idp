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
# Update kubeconfig
aws eks update-kubeconfig --name k8s-pr-0 --region us-west-2

# Verify connection
kubectl get nodes
```

### Access ArgoCD Dashboard

```bash
# Update kubeconfig if not already done
aws eks update-kubeconfig --name k8s-pr-0 --region us-west-2

# Get the admin password (Option 1: via Terraform output)
cd infra/entry
terraform output -raw argocd_server_admin_password

# Get the admin password (Option 2: via kubectl - works after CI/CD deploys too)
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# Port-forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Access at http://localhost:8080 and login with username `admin` and the password from above.

## CI/CD

GitHub Actions workflow automatically provisions infrastructure on pull requests using OIDC authentication (no long-lived credentials).

## Infrastructure Modules

- **VPC** - Network configuration with public/private subnets
- **EKS** - Kubernetes cluster
- **ArgoCD** - GitOps deployment tool

