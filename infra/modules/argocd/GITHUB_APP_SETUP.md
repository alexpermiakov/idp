# GitHub App Setup for ArgoCD Image Updater

ArgoCD Image Updater uses a GitHub App to authenticate and write image updates back to Git. This provides secure, auditable access without long-lived tokens.

## Step 1: Create GitHub App

1. Go to https://github.com/organizations/YOUR_ORG/settings/apps (or your personal account settings)
2. Click "New GitHub App"
3. Fill in:
   - **Name**: `argocd-image-updater-YOUR_CLUSTER` (must be unique)
   - **Homepage URL**: `https://argoproj.github.io/argo-cd/`
   - **Webhook**: Uncheck "Active"
4. **Repository permissions**:

   - Contents: `Read and write`
   - Metadata: `Read-only` (automatically selected)

5. **Where can this GitHub App be installed?**

   - Select "Only on this account"

6. Click "Create GitHub App"

## Step 2: Generate Private Key

1. On the app page, scroll to "Private keys"
2. Click "Generate a private key"
3. Save the downloaded `.pem` file securely

## Step 3: Install the App

1. On the app page, click "Install App" in the left sidebar
2. Select your account/organization
3. Choose "Only select repositories"
4. Select the `idp` repository
5. Click "Install"

## Step 4: Get IDs

From the app settings page, note:

- **App ID**: Visible at the top of the page
- **Installation ID**: In the URL after installing: `https://github.com/settings/installations/12345678` → Installation ID is `12345678`

## Step 5: Store Credentials in AWS SSM

**Important**: Store credentials in **each AWS account where an EKS cluster runs** (dev, staging, prod). ArgoCD Image Updater runs as a pod in the cluster and needs to access SSM parameters in the same account.

You can use the **same GitHub App for all environments** (simpler) or create separate apps per environment (more isolation).

### For your setup:

- **Dev cluster** (now): Store in **dev AWS account**
- **Staging cluster** (future): Store in **staging AWS account**
- **Prod cluster** (future): Store in **prod AWS account**
- **Tooling account** (ECR): No credentials needed there - ArgoCD reads images but doesn't write to GitHub

### Store in each cluster account:

```bash
# Set AWS profile for the target account
export AWS_PROFILE=935743309409_AdministratorAccess  # dev
# export AWS_PROFILE=470879558261_AdministratorAccess  # staging
# export AWS_PROFILE=316762121478_AdministratorAccess  # prod

# Store App ID
aws ssm put-parameter \
  --name "/idp/github-app-id" \
  --value "argocd-image-updater-k8s" \
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
```

**That's it!** Terraform is already configured to read these parameters automatically.

## How It Works

1. Image Updater uses the GitHub App credentials to generate short-lived JWT tokens
2. Exchanges JWT for installation access token (valid 1 hour)
3. Uses token to commit image updates to `idp` repo
4. Tokens rotate automatically - no long-lived credentials

