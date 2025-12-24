# Multi-Environment Image Tagging Strategy

## Overview

This IDP uses a sophisticated tagging strategy to enable automatic deployments to dev, controlled releases to staging, and manual promotion to production.

## Image Tagging in CI/CD

### On Every Commit to Main

When code is merged to `main`, CI/CD should tag the image with:

```bash
# SHA-based tag (unique identifier)
docker tag myapp:latest 864992049050.dkr.ecr.us-east-1.amazonaws.com/idp/localtime:sha-${GITHUB_SHA:0:7}
docker push 864992049050.dkr.ecr.us-east-1.amazonaws.com/idp/localtime:sha-${GITHUB_SHA:0:7}
```

**Result**: Dev environment automatically deploys this image within 2 minutes.

### On Git Tag/Release (e.g., v1.2.3)

When you create a git tag (e.g., `git tag v1.2.3`), CI/CD should tag the image with:

```bash
# Get the git tag
VERSION=${GITHUB_REF#refs/tags/}  # e.g., v1.2.3

# Tag with full semver
docker tag myapp:latest 864992049050.dkr.ecr.us-east-1.amazonaws.com/idp/localtime:${VERSION}
docker push 864992049050.dkr.ecr.us-east-1.amazonaws.com/idp/localtime:${VERSION}
```

**Result**: Staging environment automatically deploys this versioned image within 2 minutes.

## Example GitHub Actions Workflow

```yaml
name: Build and Push

on:
  push:
    branches: [main]
    tags: ["v*.*.*"]

env:
  ECR_REGISTRY: 864992049050.dkr.ecr.us-east-1.amazonaws.com
  ECR_REPOSITORY: idp/localtime

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::864992049050:role/GitHubActionsECRRole
          aws-region: us-east-1

      - name: Login to ECR
        run: |
          aws ecr get-login-password --region us-east-1 | \
            docker login --username AWS --password-stdin $ECR_REGISTRY

      - name: Build image
        run: |
          docker build -t $ECR_REPOSITORY:$GITHUB_SHA .

      - name: Tag and push images
        run: |
          # Always push SHA tag (for dev)
          docker tag $ECR_REPOSITORY:$GITHUB_SHA $ECR_REGISTRY/$ECR_REPOSITORY:sha-${GITHUB_SHA:0:7}
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:sha-${GITHUB_SHA:0:7}

          # If this is a version tag, also push semver tag (for staging)
          if [[ $GITHUB_REF == refs/tags/v* ]]; then
            VERSION=${GITHUB_REF#refs/tags/}
            docker tag $ECR_REPOSITORY:$GITHUB_SHA $ECR_REGISTRY/$ECR_REPOSITORY:$VERSION
            docker push $ECR_REGISTRY/$ECR_REPOSITORY:$VERSION
            echo "✅ Pushed version: $VERSION (will auto-deploy to staging)"
          fi
```

## Deployment Flow by Environment

### Dev Environment

- **Trigger**: Every commit to `main`
- **Image Tag Pattern**: `sha-*`
- **Update Strategy**: `latest` (always newest sha- tag)
- **Automation**: Fully automatic via ArgoCD Image Updater
- **Resources**: Small (1 replica, small resource profile)

### Staging Environment

- **Trigger**: Git tag push (e.g., `git tag v1.2.3 && git push --tags`)
- **Image Tag Pattern**: `v[0-9]+.[0-9]+.[0-9]+`
- **Update Strategy**: `semver` (only semantic versions)
- **Automation**: Fully automatic via ArgoCD Image Updater
- **Resources**: Medium (2 replicas, medium resource profile)

### Production Environment

- **Trigger**: Manual PR to update image tag in Git
- **Image Tag Pattern**: `v[0-9]+.[0-9]+.[0-9]+` (same images as staging)
- **Update Strategy**: Manual only (no Image Updater)
- **Automation**: ArgoCD syncs after PR is merged
- **Resources**: Large (3 replicas, large resource profile)

## How to Release

### To Dev (Continuous)

```bash
git add .
git commit -m "feat: new feature"
git push origin main
# ✅ Automatically deploys to dev within 2 minutes
```

### To Staging (Release)

```bash
# After code is merged to main:
git tag v1.2.3
git push origin v1.2.3
# ✅ Automatically deploys to staging within 2 minutes
```

### To Production (Manual Promotion)

```bash
# After verifying in staging:
# 1. Create PR updating prod/time-service.yaml image from v1.2.2 -> v1.2.3
# 2. Get approval
# 3. Merge PR
# ✅ ArgoCD deploys to production
```

## Benefits

✅ **Fast feedback**: Dev gets every commit automatically  
✅ **Controlled releases**: Staging only gets tagged versions  
✅ **Safety**: Production requires human approval  
✅ **Consistency**: Same image tested in staging → promoted to prod  
✅ **Audit trail**: All production deployments tracked via Git PRs

## Interview Talking Points

**"Our IDP implements a progressive delivery model:**

- **Dev environment** uses the latest commit-based images for rapid iteration
- **Staging** automatically deploys semantic versioned releases for validation
- **Production** requires manual promotion via GitOps PR for compliance and control

**This gives teams autonomy while maintaining governance. App teams can deploy to dev constantly, release to staging by tagging, but production changes are auditable and require platform team approval.**"

