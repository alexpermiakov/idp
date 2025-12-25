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

**Expected output:**

```json
{
  "OpenIDConnectProviderArn": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
}
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
          "token.actions.githubusercontent.com:sub": "repo:alexpermiakov/idp:*"
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

**Expected output:**

```json
{
  "Role": {
    "RoleName": "GitHubActionsRole",
    "Arn": "arn:aws:iam::123456789012:role/GitHubActionsRole"
  }
}
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

The tooling account only needs S3 and ECR permissions. Use least privilege:

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
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
          "ecr:DescribeRepositories"
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

---

## Step 3: Verify Setup

Copy the role ARN and update your workflow files:

**For dev account** (`.github/workflows/provision-dev.yml`):

```yaml
env:
  AWS_ROLE_ARN: arn:aws:iam::935743309409:role/GitHubActionsRole
```

**For tooling account** (`.github/workflows/provision-tooling.yml`, `.github/workflows/bootstrap-tooling.yml`):

```yaml
env:
  AWS_ROLE_ARN: arn:aws:iam::864992049050:role/GitHubActionsRole
```

---

## Account Setup Checklist

### ✅ Dev Account (935743309409)

- [x] GitHub OIDC Provider created
- [x] GitHubActionsRole created
- [x] Role ARN in `provision-dev.yml`

### ⬜ Tooling Account (864992049050)

- [ ] GitHub OIDC Provider created
- [ ] GitHubActionsRole created (limited permissions)
- [ ] Role ARN in `provision-tooling.yml` and `bootstrap-tooling.yml`

### ⬜ Staging Account (TBD)

- [ ] GitHub OIDC Provider created
- [ ] GitHubActionsRole created
- [ ] Role ARN in `provision-staging.yml`

### ⬜ Prod Account (TBD)

- [ ] GitHub OIDC Provider created
- [ ] GitHubActionsRole created
- [ ] Role ARN in `provision-prod.yml`

---

## Security Best Practices

### 1. Use Least Privilege

Instead of `AdministratorAccess`, create custom policies with only required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ec2:*", "eks:*", "iam:*", "s3:*", "ecr:*"],
      "Resource": "*"
    }
  ]
}
```

### 2. Restrict by Branch

Modify trust policy to only allow `main` branch:

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:alexpermiakov/idp:ref:refs/heads/main"
  }
}
```

### 3. Enable CloudTrail

Monitor all actions taken by GitHub Actions:

```bash
aws cloudtrail create-trail \
  --name github-actions-audit \
  --s3-bucket-name my-cloudtrail-bucket
```

---

## Troubleshooting

### "Not authorized to perform: sts:AssumeRoleWithWebIdentity"

**Cause**: Trust policy doesn't allow your repository or the OIDC provider doesn't exist.

**Fix**:

1. Check OIDC provider exists: `aws iam list-open-id-connect-providers`
2. Verify repository name in trust policy matches: `alexpermiakov/idp`
3. Check role ARN in workflow matches the actual role ARN

### "No valid credential sources found"

**Cause**: Workflow can't assume the role.

**Fix**:

1. Verify `id-token: write` permission in workflow
2. Check `audience: sts.amazonaws.com` is set
3. Confirm role ARN is correct

---

## Why Can't This Be Automated?

**Chicken and egg problem:**

- Terraform needs AWS credentials to run
- GitHub Actions needs the OIDC + Role to get credentials
- Can't create OIDC + Role with Terraform because... no credentials yet!

**Solutions:**

1. ✅ **Manual setup** (current approach) - Do once per account
2. ⚠️ **CloudFormation StackSets** - Use AWS Organizations to deploy across accounts
3. ⚠️ **AWS CLI + Script** - Still requires manual AWS credentials initially
4. ⚠️ **Terraform Cloud** - Use Terraform Cloud with stored AWS credentials

For most teams, **manual setup once per account** is the simplest approach.

---

## Next Steps

After completing this setup for an account:

1. **Dev account**: Create PR to run `provision-dev.yml`
2. **Tooling account**: Run `bootstrap-tooling.yml` then `provision-tooling.yml`
3. **Staging/Prod**: Repeat this process when ready to create those accounts

