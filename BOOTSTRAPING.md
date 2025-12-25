# AWS Account Bootstrap Guide

This guide covers the **one-time manual setup** required for each AWS account before you can use GitHub Actions to provision infrastructure.

## The Bootstrapping Problem

To run Terraform via GitHub Actions, you need:

1. **GitHub OIDC Provider** in AWS (for passwordless authentication)
2. **GitHubActionsRole** with permissions to run Terraform

But you can't create these with Terraform because... you need them to run Terraform!

So these must be created **manually once per AWS account**.

---

## Prerequisites

- AWS account with admin access
- AWS CLI installed locally
- Your GitHub repository: `alexpermiakov/idp`

---

## Step 1: Create GitHub OIDC Provider

Run this **once per AWS account** (dev, staging, prod, tooling):

```bash
# Authenticate to the target AWS account
aws sso login --profile <account-profile>  # or your auth method

# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Setting up OIDC in account: $AWS_ACCOUNT_ID"

# Create OIDC provider for GitHub Actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --tags Key=Name,Value=GitHubActionsOIDC
```

---

## Step 2: Create GitHubActionsRole

**Step 2.1: Create trust policy and role** (same for all accounts):

```bash
# Get account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create trust policy inline
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

# Clean up
rm github-actions-trust-policy.json
```

---

**Step 2.2: Attach permissions** (differs by account type):

### A. For Dev/Staging/Prod Accounts (EKS Clusters)

These accounts need broad permissions to manage VPC, EKS, ArgoCD, etc.:

```bash
# Attach AdministratorAccess (or create a more restricted policy)
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### B. For Tooling Account (ECR Only)

The tooling account only needs S3 and ECR permissions:

```bash
# Create custom policy inline
aws iam create-policy \
  --policy-name GitHubActionsToolingPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["s3:*"],
        "Resource": [
          "arn:aws:s3:::terraform-state-alexidp-tooling",
          "arn:aws:s3:::terraform-state-alexidp-tooling/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:DescribeRepositories",
          "ecr:ListTagsForResource",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:PutImageTagMutability",
          "ecr:PutImageScanningConfiguration",
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        "Resource": "*"
      }
    ]
  }'

# Get the policy ARN and attach it
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='GitHubActionsToolingPolicy'].Arn" --output text)

aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn $POLICY_ARN
```

