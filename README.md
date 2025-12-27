# IDP Architecture - Multi-Account, Multi-Cluster

## Overview

This IDP uses a **distributed ArgoCD architecture** with one ArgoCD instance per cluster, deployed across three AWS accounts.

## AWS Account Structure

This setup requires **5 AWS accounts** organized under AWS Organizations:

- **Main Account** - AWS Organization root account (management account)
- **Dev Account** - Development environment with EKS cluster
- **Staging Account** - Staging environment with EKS cluster
- **Prod Account** - Production environment with EKS cluster
- **Tooling Account** - Shared services (ECR container registry, CI/CD artifacts)

All accounts are managed under AWS Organizations for centralized billing and governance.

## Application Deployment (ArgoCD + GitOps)

Each ArgoCD instance is configured differently:

#### Dev ArgoCD

- Watches: `argocd/applications/dev/`
- Git Branch: PR branches (ephemeral dev cluster per PR)
- Deployment: Automatic on PR creation → Destroyed on PR merge/close
- Sync: Fully automated (prune + self-heal)
- Purpose: App teams can test changes immediately without platform team involvement

#### Staging ArgoCD

- Watches: `argocd/applications/staging/`
- Git Branch: `main`
- Deployment: Automatic on PR merge → Deploys to persistent staging cluster
- Sync: Fully automated
- Purpose: Pre-production validation

#### Prod ArgoCD

- Watches: `argocd/applications/prod/`
- Git Target: Semver tags (e.g., `v1.2.3`)
- Deployment: Platform team promotes via PR (controlled release)
- Sync: Fully automated

## Deployment Flow (Pure GitOps)

### 1. App Team Releases New Version

```
App Team Repository (e.g., my-service service):
1. Developer tags release: git tag v1.2.3
2. GitHub Actions workflow automatically:
   - Builds Docker image
   - Pushes to ECR: AWS_TOOLING_ACC_ID.dkr.ecr.us-west-2.amazonaws.com/idp/my-service:v1.2.3
   - Clones platform repo (github.com/alexpermiakov/idp)
   - Updates argocd/applications/dev/my-service.yaml with new image tag
   - Opens PR: "🚀 Deploy my-service v1.2.3 to dev"
```

### 2. Automatic Dev Cluster Creation & Deployment

```
Automatic:
1. PR is opened → New ephemeral dev k8s cluster is created for this PR
2. Dev ArgoCD detects changes and syncs → Deploys to the PR's dev cluster
3. App team can test changes immediately
```

### 3. Platform Team Merges & Promotes to Staging

```
Platform Team:
1. Reviews PR and validates deployment in dev cluster
2. Merges PR → Ephemeral dev cluster is destroyed
3. Staging ArgoCD detects change → Syncs → Deploys to staging cluster
```

---

## Setup

### 1. App Team Onboarding

For app teams to deploy their services, see the complete guide:

- **[CI Workflow Template](docs/app-team-ci-workflow.yaml)** - GitHub Actions workflow

**Quick Summary:** App teams set up a GitHub Actions workflow that automatically opens PRs to this platform repo when they tag releases. Platform team reviews and merges PRs to trigger deployments.

---

### 2. AWS Account Bootstrap for GitHub Actions

**Do this once per AWS account** to enable GitHub Actions to deploy infrastructure via Terraform.

#### Prerequisites

- AWS account with admin access
- AWS CLI installed locally
- Your GitHub repository: `alexpermiakov/idp`

#### Step 1: Create GitHub OIDC Provider

```bash
# Set AWS profile for the target account (credentials in ~/.aws/credentials)
export AWS_PROFILE=935743309409_AdministratorAccess  # dev
# export AWS_PROFILE=470879558261_AdministratorAccess  # staging
# export AWS_PROFILE=316762121478_AdministratorAccess  # prod

# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Setting up OIDC in account: $AWS_ACCOUNT_ID"

# Create OIDC provider for GitHub Actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --tags Key=Name,Value=GitHubActionsOIDC
```

#### Step 2: Create GitHubActionsRole

```bash
# Get account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create trust policy
cat > github-actions-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:alexpermiakov/*"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-actions-trust-policy.json \
  --description "Role for GitHub Actions to manage infrastructure"

# Attach AdministratorAccess
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Clean up
rm github-actions-trust-policy.json
```

**Done!** GitHub Actions can now deploy infrastructure via Terraform.

---

## Usage

### Connect to EKS Cluster

After deployment:

```bash
Visit https://d-9267ef45c3.awsapps.com/start, click "Access keys", and copy the credentials.

export AWS_PROFILE=935743309409_AdministratorAccess

# Verify AWS access
aws sts get-caller-identity

# Update kubeconfig - replace <PR> with your PR number
aws eks update-kubeconfig --region us-west-2 --name k8s-pr-<PR>

# Verify connection
kubectl get nodes
```

### Access ArgoCD Dashboard

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# Port-forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
```

Access at http://localhost:8080 and login with username `admin` and the password from above.

