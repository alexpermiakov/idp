# Pod Identity Configuration

This Terraform module creates Pod Identity associations for manually deployed EKS clusters.

## Usage

1. Authenticate to AWS (using SSO or credentials)
2. Run:

```bash
terraform init
terraform apply -var="cluster_name=YOUR_CLUSTER_NAME"
```

## What it creates

- IAM role with ECR pull permissions
- Pod Identity associations for:
  - `time-service` in `time-service-dev` namespace
  - `version-service` in `version-service-dev` namespace

## After applying

Restart your deployments:
```bash
kubectl rollout restart deployment/time-service -n time-service-dev
kubectl rollout restart deployment/version-service -n version-service-dev
```
