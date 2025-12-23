# Platform Golden Helm Chart

This is the **Platform Team's standardized Helm chart** for all Go microservices.

## Key Concept: Zero K8s Knowledge Required for App Teams

App teams write **ZERO Kubernetes or Helm files**. They only maintain application code.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  IDP Repo (Platform Team)                                    │
│                                                              │
│  ├── helm-charts/                                            │
│  │   └── standard-service/  ← Golden chart (ONE template)    │
│  │       ├── Chart.yaml                                      │
│  │       ├── values.yaml    ← Defaults for all services      │
│  │       └── templates/                                      │
│  │           ├── deployment.yaml                             │
│  │           ├── service.yaml                                │
│  │           ├── hpa.yaml                                    │
│  │           └── ingress.yaml                                │
│  │                                                           │
│  └── argocd/                                                 │
│      └── applications/                                       │
│          ├── time-service.yaml                               │
│          └── version-service.yaml                            │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  App Repos (Dev Teams)                                       │
│                                                              │
│  local-time-go-server/                                       │
│  ├── main.go            ← Just application code              │
│  ├── go.mod                                                  │
│  ├── Dockerfile                                               │
│  └── NO k8s/ or helm/ directories!                           │
└──────────────────────────────────────────────────────────────┘
```

## What App Teams Do

To deploy a new service, the app team just need to add ONE file to the IDP repo:

```yaml
# argocd/applications/new-service.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: new-service
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/repourl
    path: helm-charts/standard-service
    helm:
      values: |
        app:
          name: new-service
          image: registry/new-service:v1.0.0
          port: 8080
        resourceProfile: medium
```

Everything else (deployment, service, HPA, security, monitoring) comes from the golden chart.

## Resource Profiles

Platform team defines three tiers:

| Profile  | CPU Limit | Memory Limit | Use Case              |
| -------- | --------- | ------------ | --------------------- |
| `small`  | 100m      | 128Mi        | Low-traffic services  |
| `medium` | 200m      | 256Mi        | Standard services     |
| `large`  | 500m      | 512Mi        | High-traffic services |

App teams just choose a profile - no need to understand K8s resources.

## What's Included (Automatically)

Every service gets:

✅ **Security best practices**

- Non-root user
- Read-only filesystem
- Dropped capabilities

✅ **Health checks**

- Liveness probe on `/health`
- Readiness probe on `/ready`

✅ **Monitoring**

- Prometheus scraping enabled
- Metrics on `/metrics`

✅ **High availability**

- Pod anti-affinity (spread across nodes)
- Horizontal Pod Autoscaler (2-10 pods)

✅ **Ingress support**

- TLS/SSL ready
- cert-manager integration

## Evolution Path

**Phase 1** (current): Golden chart with profiles
**Phase 2**: Add environment-specific overlays (dev/staging/prod)
**Phase 3**: Policy as code (OPA) for additional guardrails
**Phase 4**: ApplicationSet for auto-discovery from GitHub org

