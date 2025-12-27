# IDP Architecture - Multi-Account, Multi-Cluster

## Overview

This IDP uses a **distributed ArgoCD architecture** with one ArgoCD instance per cluster, deployed across three AWS accounts.

## Infrastructure Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                            │
│                    github.com/alexpermiakov/idp                      │
│                                                                       │
│  - infra/                  (Terraform for all environments)          │
│  - argocd/applications/    (ArgoCD manifests by environment)         │
│  - helm-charts/            (Shared Helm charts)                      │
│  - .github/workflows/      (Provision workflows for each env)        │
└────────────────────┬────────────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┬──────────────────┐
        │                         │                  │
┌───────▼──────────┐     ┌────────▼─────────┐  ┌────▼────────────────┐
│  Dev Account     │     │ Staging Account  │  │  Prod Account       │
│  AWS 935...      │     │  AWS ???         │  │  AWS ???            │
│                  │     │                  │  │                     │
│  ┌────────────┐  │     │  ┌────────────┐  │  │  ┌────────────┐    │
│  │ EKS Cluster│  │     │  │ EKS Cluster│  │  │  │ EKS Cluster│    │
│  │            │  │     │  │            │  │  │  │            │    │
│  │ ┌────────┐ │  │     │  │ ┌────────┐ │  │  │  │ ┌────────┐ │    │
│  │ │ArgoCD  │ │  │     │  │ │ArgoCD  │ │  │  │  │ │ArgoCD  │ │    │
│  │ │        │ │  │     │  │ │        │ │  │  │  │ │        │ │    │
│  │ │Watches:│ │  │     │  │ │Watches:│ │  │  │  │ │Watches:│ │    │
│  │ │argocd/ │ │  │     │  │ │argocd/ │ │  │  │  │ │argocd/ │ │    │
│  │ │apps/   │ │  │     │  │ │apps/   │ │  │  │  │ │apps/   │ │    │
│  │ │dev/    │ │  │     │  │ │staging/│ │  │  │  │ │prod/   │ │    │
│  │ └────────┘ │  │     │  │ └────────┘ │  │  │  │ └────────┘ │    │
│  │            │  │     │  │            │  │  │  │            │    │
│  │ Apps:      │  │     │  │ Apps:      │  │  │  │ Apps:      │    │
│  │ - time-svc │  │     │  │ - time-svc │  │  │  │ - time-svc │    │
│  │ - ver-svc  │  │     │  │ - ver-svc  │  │  │  │ - ver-svc  │    │
│  └────────────┘  │     │  └────────────┘  │  │  └────────────┘    │
└──────────────────┘     └──────────────────┘  └─────────────────────┘
```

## AWS Account Structure

This setup requires **5 AWS accounts** organized under AWS Organizations:

- **Main Account** - AWS Organization root account (management account)
- **Dev Account** - Development environment with EKS cluster
- **Staging Account** - Staging environment with EKS cluster
- **Prod Account** - Production environment with EKS cluster
- **Tooling Account** - Shared services (ECR container registry, CI/CD artifacts)

All accounts are managed under AWS Organizations for centralized billing and governance.

## Deployment Strategy

### Infrastructure Provisioning (Terraform)

Each environment gets provisioned independently via GitHub Actions:

- **`.github/workflows/provision-dev.yml`** → Provisions dev account (935743309409)
- **`.github/workflows/provision-staging.yml`** → Provisions staging account (TBD)
- **`.github/workflows/provision-prod.yml`** → Provisions prod account (TBD)

Each workflow:

1. Runs on merge to `main` (or manual trigger)
2. Authenticates to the target AWS account via OIDC
3. Runs `terraform apply` in `infra/entry/`
4. Creates: VPC, EKS, ArgoCD, ECR Pod Identity

### Application Deployment (ArgoCD + GitOps)

Each ArgoCD instance is configured differently:

#### Dev ArgoCD

- Watches: `argocd/applications/dev/`
- Git Branch: Dynamic (PR branches)
- Deployment: App team CI opens PR with new image tags
- Sync: Fully automated (prune + self-heal)
- Purpose: Fast iteration and testing

#### Staging ArgoCD

- Watches: `argocd/applications/staging/`
- Git Branch: `main`
- Deployment: Platform team promotes via PR
- Sync: Fully automated
- Purpose: Pre-production validation

#### Prod ArgoCD

- Watches: `argocd/applications/prod/`
- Git Target: Semver tags (e.g., `v1.2.3`)
- Deployment: Platform team promotes via PR (controlled release)
- Sync: Fully automated
- Purpose: Production workloads with immutable releases

### What Each ArgoCD Watches

All ArgoCD instances watch the **same Git repository**, but different paths:

```yaml
# Dev ArgoCD ApplicationSet
spec:
  source:
    repoURL: https://github.com/alexpermiakov/idp
    targetRevision: main
    path: "argocd/applications/dev"  # ← Only dev apps

# Staging ArgoCD ApplicationSet
spec:
  source:
    repoURL: https://github.com/alexpermiakov/idp
    targetRevision: main
    path: "argocd/applications/staging"  # ← Only staging apps

# Prod ArgoCD ApplicationSet
spec:
  source:
    repoURL: https://github.com/alexpermiakov/idp
    targetRevision: main
    path: "argocd/applications/prod"  # ← Only prod apps
```

## Deployment Flow (Pure GitOps)

### 1. App Team Releases New Version

```
App Team Repository (e.g., localtime service):
1. Developer tags release: git tag v1.2.3
2. GitHub Actions workflow automatically:
   - Builds Docker image
   - Pushes to ECR: 864992049050.dkr.ecr.us-west-2.amazonaws.com/idp/localtime:v1.2.3
   - Clones platform repo (github.com/alexpermiakov/idp)
   - Updates argocd/applications/dev/time-service.yaml with new image tag
   - Opens PR: "🚀 Deploy time-service v1.2.3 to dev"
```

### 2. Platform Team Reviews & Deploys to Dev

```
Platform Team:
3. Reviews auto-generated PR
4. Validates: image exists in ECR, semver is valid
5. Merges PR → Commit to main branch
6. Dev ArgoCD detects change → Syncs → Deploys to dev cluster
```

### 3. Promotion to Staging

````
Platform Team:
7. Validates dev deployment
8. Opens PR updating argocd/applic

**Do this once per AWS account (dev/staging/prod).** ArgoCD uses a GitHub App to authenticate and read repository manifests. This provides secure, auditable access without long-lived tokens.

#### Create GitHub App

1. Go to https://github.com/organizations/YOUR_ORG/settings/apps (or your personal account settings)
2. Click "New GitHub App"
3. Fill in:
   - **Name**: `argocd-YOUR_CLUSTER` (must be unique)
   - **Homepage URL**: `https://argoproj.github.io/argo-cd/`
   - **Webhook**: Uncheck "Active"
4. **Repository permissions**:
   - Contents: `Read-only`
   - Metadata: `Read-only` (automatically selected)
5. **Where can this GitHub App be installed?**: Select "Only on this account"
6. Click "Create GitHub App"

#### Generate Private Key

1. On the app page, scroll to "Private keys"
2. Click "Generate a private key"
3. Save the downloaded `.pem` file securely

#### Install the App

1. On the app page, click "Install App" in the left sidebar
2. Select your account/organization
3. Choose "Only select repositories"
4. Select the `idp` repository
5. Click "Install"

#### Get IDs

From the app settings page, note:

- **App ID**: Visible at the top of the page
- **Installation ID**: In the URL after installing: `https://github.com/settings/installations/12345678` → Installation ID is `12345678`

#### Store Credentials in AWS SSM

**Important**: Store credentials in **each AWS account where an EKS cluster runs** (dev, staging, prod). ArgoCD runs as a pod in the cluster and needs to access SSM parameters in the same account.

You can use the **same GitHub App for all environments** (simpler) or create separate apps per environment (more isolation).

```bash
# Set AWS profile for the target account
export AWS_PROFILE=935743309409_AdministratorAccess  # dev
# export AWS_PROFILE=470879558261_AdministratorAccess  # staging
# export AWS_PROFILE=316762121478_AdministratorAccess  # prod

# Store App ID
aws ssm put-parameter \
  --name "/idp/github-app-id" \
  --value "YOUR_APP_ID" \
  --type "String" \
  --region us-west-2 \
  --overwrite

# Store Installation ID
aws ssm put-parameter \
  --name "/idp/github-app-installation-id" \
  --value "YOUR_INSTALLATION_ID" \
  --type "String" \
  --region us-west-2 \
  --overwrite

# Store Private Key (entire PEM file)
aws ssm put-parameter \
  --name "/idp/github-app-private-key" \
  --value "$(cat /path/to/your-app.pem)" \
  --type "SecureString" \
  --region us-west-2 \
  --overwrite
````

**Notes:**

- No special roles or infrastructure needed - just AWS CLI access with SSM permissions
- This is a one-time setup per AWS account
- Terraform will read these parameters when deploying ArgoCD

---

### 2. App Team Onboarding

For app teams to deploy their services, see the complete guide:

- **[App Team Onboarding Guide](docs/app-team-onboarding.md)** - Full setup instructions
- **[CI Workflow Template](docs/app-team-ci-workflow.yaml)** - GitHub Actions workflow

**Quick Summary:** App teams set up a GitHub Actions workflow that automatically opens PRs to this platform repo when they tag releases. Platform team reviews and merges PRs to trigger deployments.

---

### 3sm put-parameter \

--name "/idp/github-app-installation-id" \
 --value "YOUR_INSTALLATION_ID" \
 --type "String" \
 --region us-west-2 \
 --overwrite

# Store Private Key (entire PEM file)

aws ssm put-parameter \
 --name "/idp/github-app-private-key" \
 --value "$(cat /path/to/your-app.pem)" \
 --type "SecureString" \
 --region us-west-2 \
 --overwrite

````

**Notes:**

- No special roles or infrastructure needed - just AWS CLI access with SSM permissions
- This is a one-time setup per AWS account
- Terraform will read these parameters when deploying ArgoCD

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
````

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

