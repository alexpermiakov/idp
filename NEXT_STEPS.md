# Implementation Steps - Multi-Environment ArgoCD

## Current Problem

Your ApplicationSet is configured to deploy **all environments** (dev, staging, prod) to the **same cluster**:

```yaml
# argocd/applicationset.yaml
generators:
  - list:
      elements:
        - environment: dev
        - environment: staging
        - environment: prod
```

But you only have **one cluster** (dev). This creates confusion.

## Two Paths Forward

### Path A: Quick Fix (Single Cluster, Multiple Namespaces) - SIMPLER

Keep everything in one cluster for now, different namespaces per environment.

**Pros:** Works with what you have, simpler, cheaper
**Cons:** All environments share same cluster resources

### Path B: Production-Grade (Multiple Clusters) - RECOMMENDED

Deploy separate clusters for dev/staging/prod in different AWS accounts.

**Pros:** True isolation, production-ready architecture
**Cons:** More complex, more expensive, more to manage

---

## 🎯 RECOMMENDED: Path B (Multi-Cluster)

Here's the step-by-step implementation:

### Phase 1: Fix Current Dev Setup ✅ (DONE)

- [x] Update ECR Pod Identity for environment-specific namespaces
- [ ] Apply Terraform changes
- [ ] Restart time-service deployment

### Phase 2: Prepare for Multi-Cluster

#### 2.1 Update ApplicationSet Strategy

Currently your ApplicationSet tries to deploy all envs to one cluster:

```yaml
# argocd/applicationset.yaml - CURRENT (WRONG)
generators:
  - list:
      elements:
        - environment: dev # ← Deploys to THIS cluster
        - environment: staging # ← Tries to deploy to THIS cluster (wrong!)
        - environment: prod # ← Tries to deploy to THIS cluster (wrong!)
```

**Fix:** Remove the ApplicationSet entirely. Replace with environment-specific bootstrapping:

```yaml
# argocd/bootstrap-dev.yaml - NEW
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/alexpermiakov/idp
    targetRevision: main
    path: "argocd/applications/dev" # ← Only dev apps
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Create separate files:

- `argocd/bootstrap-dev.yaml` → Applied to dev cluster
- `argocd/bootstrap-staging.yaml` → Applied to staging cluster
- `argocd/bootstrap-prod.yaml` → Applied to prod cluster

#### 2.2 Update Terraform to Apply Bootstrap

Modify `infra/modules/argocd/main.tf` to accept an environment variable and apply the correct bootstrap:

```terraform
variable "environment" {
  description = "Environment name: dev, staging, or prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# Apply environment-specific bootstrap
resource "kubernetes_manifest" "bootstrap" {
  manifest = yamldecode(file("${path.module}/../../argocd/bootstrap-${var.environment}.yaml"))

  depends_on = [helm_release.argocd]
}
```

### Phase 3: Set Up Staging & Prod AWS Accounts

#### 3.1 Create Staging AWS Account

1. Create new AWS account (or use existing)
2. Set up GitHub OIDC provider
3. Create `GitHubActionsRole` for Terraform
4. Note the account ID (e.g., `123456789012`)

#### 3.2 Create Prod AWS Account

1. Create new AWS account (or use existing)
2. Set up GitHub OIDC provider
3. Create `GitHubActionsRole` for Terraform
4. Note the account ID (e.g., `987654321098`)

#### 3.3 Create S3 Terraform State Buckets

In each account:

```bash
# Staging account
aws s3 mb s3://terraform-state-alexidp-staging --region us-west-2

# Prod account
aws s3 mb s3://terraform-state-alexidp-prod --region us-west-2
```

### Phase 4: Create Provision Workflows

#### 4.1 Create `.github/workflows/provision-staging.yml`

```yaml
name: Provision Staging

on:
  workflow_dispatch: # Manual trigger only
  push:
    tags:
      - "infra-v*" # Or trigger on infrastructure version tags

env:
  AWS_REGION: us-west-2
  AWS_ROLE_ARN: arn:aws:iam::STAGING_ACCOUNT_ID:role/GitHubActionsRole
  ENVIRONMENT: staging

jobs:
  provision:
    name: Provision Staging Infrastructure
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v5.1.1
        with:
          role-to-assume: ${{ env.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.3

      - name: Terraform Init
        working-directory: infra/entry
        run: |
          terraform init \
            -backend-config="region=${{ env.AWS_REGION }}" \
            -backend-config="bucket=terraform-state-alexidp-staging" \
            -backend-config="key=staging/state.tfstate"

      - name: Terraform Plan
        working-directory: infra/entry
        run: |
          terraform plan \
            -var='environment=staging' \
            -var='admin_role_arns=["arn:aws:iam::STAGING_ACCOUNT_ID:role/AdminRole"]'

      - name: Wait for Approval
        uses: trstringer/manual-approval@v1
        with:
          secret: ${{ secrets.GITHUB_TOKEN }}
          approvers: alexpermiakov
          minimum-approvals: 1

      - name: Terraform Apply
        working-directory: infra/entry
        run: |
          terraform apply -auto-approve \
            -var='environment=staging' \
            -var='admin_role_arns=["arn:aws:iam::STAGING_ACCOUNT_ID:role/AdminRole"]'
```

#### 4.2 Create `.github/workflows/provision-prod.yml`

Similar to staging but with:

- Prod account ID
- Stricter approval gates
- Maybe multiple approvers

### Phase 5: Update Terraform Entry Point

Modify `infra/entry/main.tf` to accept environment variable:

```terraform
variable "environment" {
  description = "Environment: dev, staging, or prod"
  type        = string
  default     = "dev"
}

# Pass to ArgoCD module
module "argocd" {
  source = "../modules/argocd"

  environment     = var.environment
  cluster_name    = module.eks.cluster_name
  github_app_id   = var.github_app_id
  # ... other vars
}

# Pass to ECR module
module "ecr_pod_identity" {
  source = "../modules/ecr-pod-identity"

  cluster_name    = module.eks.cluster_name
  ecr_account_id  = var.ecr_account_id
  environment     = var.environment  # New parameter
}
```

Update `infra/modules/ecr-pod-identity/main.tf` to create associations based on environment:

```terraform
variable "environment" {
  description = "Environment name"
  type        = string
}

# Dynamic namespace based on environment
locals {
  namespaces = {
    dev     = ["time-service-dev", "version-service-dev"]
    staging = ["time-service-staging", "version-service-staging"]
    prod    = ["time-service-prod", "version-service-prod"]
  }

  target_namespaces = local.namespaces[var.environment]
}

# Create pod identity associations for each service in this environment
resource "aws_eks_pod_identity_association" "time_service" {
  cluster_name    = var.cluster_name
  namespace       = "${var.environment == "dev" ? "time-service-dev" : var.environment == "staging" ? "time-service-staging" : "time-service-prod"}"
  service_account = "time-service"
  role_arn        = aws_iam_role.ecr_pull.arn
}

resource "aws_eks_pod_identity_association" "version_service" {
  cluster_name    = var.cluster_name
  namespace       = "${var.environment == "dev" ? "version-service-dev" : var.environment == "staging" ? "version-service-staging" : "version-service-prod"}"
  service_account = "version-service"
  role_arn        = aws_iam_role.ecr_pull.arn
}
```

### Phase 6: Deploy!

#### 6.1 Deploy Staging

1. Run workflow: `.github/workflows/provision-staging.yml`
2. Approve the manual gate
3. Wait for EKS + ArgoCD to come up
4. Verify ArgoCD is watching `argocd/applications/staging/`

#### 6.2 Deploy Prod

1. Run workflow: `.github/workflows/provision-prod.yml`
2. Get approval from team
3. Wait for EKS + ArgoCD to come up
4. Verify ArgoCD is watching `argocd/applications/prod/`

---

## 🚀 Quick Start (Just Fix Dev First)

If you want to fix dev before thinking about staging/prod:

### Step 1: Apply Current Terraform Fix

```bash
cd /Users/alex/projects/idp/infra/entry

# Configure AWS credentials for dev account
export AWS_PROFILE=dev  # or however you auth

# Initialize and apply
terraform init \
  -backend-config="region=us-west-2" \
  -backend-config="bucket=terraform-state-alexidp-dev" \
  -backend-config="key=dev/state.tfstate"

terraform apply \
  -var='admin_role_arns=["arn:aws:iam::935743309409:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_AdministratorAccess_82ac38af355c29a0"]'
```

### Step 2: Restart Deployment

```bash
kubectl config use-context <your-dev-cluster>
kubectl rollout restart deployment/time-service -n time-service-dev
```

### Step 3: Check Logs

```bash
kubectl get pods -n time-service-dev
kubectl describe pod <pod-name> -n time-service-dev
```

The 403 error should be gone!

---

## Decision Time

**What do you want to do?**

A. Fix dev cluster now, think about multi-cluster later
B. Implement full multi-cluster architecture now
C. Something else?

Let me know and I'll help you execute!

