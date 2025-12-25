# Tooling Account ECR Cross-Account Access

This Terraform configuration manages ECR repository policies in the **tooling account (864992049050)** to allow other accounts (dev, staging, prod) to pull images.

## Prerequisites

1. **GitHub OIDC Provider** must be set up in tooling account (864992049050)
2. **GitHubActionsRole** must exist in tooling account with permissions to manage S3 and ECR

## Setup Process

### Step 1: Bootstrap Backend (One-Time)

1. Go to GitHub Actions → "Bootstrap Tooling Backend"
2. Click "Run workflow"
3. Creates `terraform-state-alexidp-tooling` S3 bucket

### Step 2: Apply Tooling Infrastructure

- **Manual**: GitHub Actions → "Provision Tooling" → "Run workflow"
- **Automatic**: Push changes to `infra/tooling/` on `main` branch

## What It Does

- Adds ECR repository policies to `idp/localtime` and `idp/version`
- Allows dev account (935743309409) to pull images

## When to Update

- **New environment**: Add account ARN to `Principal.AWS` in main.tf
- **New ECR repo**: Add new `aws_ecr_repository_policy` resource

