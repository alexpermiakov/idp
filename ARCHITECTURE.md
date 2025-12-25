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

### Application Deployment (ArgoCD)

Each ArgoCD instance is configured differently:

#### Dev ArgoCD

- Watches: `argocd/applications/dev/`
- Auto-deploys: Latest `sha-*` tagged images
- Sync: Fully automated (prune + self-heal)
- Purpose: Continuous deployment from `main`

#### Staging ArgoCD

- Watches: `argocd/applications/staging/`
- Auto-deploys: Semantic version tags (e.g., `v1.2.3`)
- Sync: Fully automated
- Purpose: Release candidate testing

#### Prod ArgoCD

- Watches: `argocd/applications/prod/`
- Deploys: Pinned stable versions
- Sync: Manual approval required (or automated with extra checks)
- Purpose: Production workloads

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

## Image Promotion Flow

```
1. Commit to main
   └─> CI builds & tags: sha-714f35e
       └─> ArgoCD Image Updater (Dev) detects new sha-* tag
           └─> Updates argocd/applications/dev/time-service.yaml
               └─> Dev ArgoCD syncs → Deploys to dev cluster

2. Git tag v1.2.3
   └─> CI tags same image: v1.2.3
       └─> ArgoCD Image Updater (Staging) detects new v* tag
           └─> Updates argocd/applications/staging/time-service.yaml
               └─> Staging ArgoCD syncs → Deploys to staging cluster

3. Manual promotion to prod
   └─> Engineer updates argocd/applications/prod/time-service.yaml
       └─> Changes image to v1.2.3
           └─> Creates PR & merges
               └─> Prod ArgoCD syncs → Deploys to prod cluster
```

## Why This Architecture?

### ✅ Benefits

- **Blast radius containment**: Dev ArgoCD can't affect prod
- **Account isolation**: Each environment in separate AWS account
- **Simpler networking**: No cross-account kubeconfig management
- **Independent operations**: Can upgrade dev ArgoCD without prod impact
- **Clear RBAC boundaries**: Dev team → dev account only

### ⚠️ Trade-offs

- **Multiple dashboards**: Need to check 3 ArgoCD UIs
- **More maintenance**: 3 ArgoCD instances to upgrade
- **Duplicate config**: Same ArgoCD settings in each cluster

## GitHub Actions Strategy

You need **three provision workflows**:

1. **provision-dev.yml** (exists)

   - Trigger: Push to `main` or manual
   - Target: Dev account (935743309409)
   - Risk: Low (can break dev freely)

2. **provision-staging.yml** (create)

   - Trigger: Manual only (or on git tag)
   - Target: Staging account
   - Risk: Medium (affects QA/testing)

3. **provision-prod.yml** (create)
   - Trigger: Manual only + approval gate
   - Target: Prod account
   - Risk: High (affects production)

## Bootstrap Process

### For Each New Environment:

1. **Set up AWS account & OIDC trust**

   ```bash
   # In target AWS account, create GitHub OIDC provider
   # and role for GitHub Actions
   ```

2. **Run provision workflow**

   ```bash
   # Triggers: .github/workflows/provision-{env}.yml
   # Creates: VPC, EKS, ArgoCD
   ```

3. **ArgoCD auto-configures itself**

   ```bash
   # Terraform applies: argocd/applicationset.yaml
   # ApplicationSet creates apps from: argocd/applications/{env}/
   ```

4. **Applications self-deploy**
   ```bash
   # ArgoCD Image Updater watches ECR
   # Detects new images matching tag pattern
   # Updates manifests → ArgoCD syncs
   ```

## Day 2 Operations

### Adding New Service

1. Create Helm values in `argocd/applications/{dev,staging,prod}/new-service.yaml`
2. Commit to main
3. Each ArgoCD automatically detects and deploys to its cluster

### Updating Infrastructure

1. Modify `infra/` Terraform
2. Run provision workflow for target environment
3. Terraform updates EKS/VPC/etc.

### Promoting Version

1. Dev: Automatic (sha-\* tags)
2. Staging: Automatic (v\* tags)
3. Prod: Manual PR to update image tag

## Current vs Target State

### ✅ Current State (What You Have)

- Dev account with EKS cluster
- ArgoCD installed in dev cluster
- ApplicationSet watching all environments (but only dev works)
- ECR Pod Identity configured for wrong namespaces
- One provision workflow (dev only)

### 🎯 Target State (What You Need)

- Three accounts: dev (935...), staging (???), prod (???)
- Three EKS clusters (one per account)
- Three ArgoCD instances (one per cluster)
- Each ArgoCD watches only its environment path
- Three provision workflows (one per environment)
- ECR Pod Identity per environment namespace

## Next Steps

See [NEXT_STEPS.md](NEXT_STEPS.md) for implementation plan.

