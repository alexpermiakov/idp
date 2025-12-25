# ArgoCD Module

Deploys ArgoCD to the EKS cluster for GitOps continuous delivery.

## Configuration

- **Namespace**: `argocd`
- **Service Type**: ClusterIP (private, not exposed to internet)
- **Chart Version**: 9.1.9
- **Insecure Mode**: Enabled (HTTP, no TLS)

## Outputs

- `argocd_server_admin_password` - Initial admin password
- `namespace` - Kubernetes namespace
- `release_name` - Helm release name

## Accessing ArgoCD

ArgoCD is not exposed to the internet. Access via port-forward:

```bash
# Get admin password
terraform output -raw argocd_server_admin_password

# Port-forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at https://localhost:8080 and login with username `admin` and the password from above.

## Security Considerations

- ✅ Service is ClusterIP - not exposed to the internet
- ✅ Access only via kubectl port-forward (requires EKS authentication)
- Admin password is auto-generated and stored in Kubernetes secret `argocd-initial-admin-secret`
- Insecure mode is enabled (HTTP) - for production, consider enabling TLS

## Cleanup / Destruction

The module includes automatic cleanup procedures to handle ArgoCD's finalizers and CRDs during `terraform destroy`:

1. Removes finalizers from all Applications and ApplicationSets
2. Deletes all ArgoCD custom resources
3. Removes CRDs that Helm keeps by default
4. Namespace deletion timeout is set to 15 minutes

If you still encounter issues during destroy, you can manually clean up:

```bash
# Remove finalizers from applications
kubectl get applications.argoproj.io -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read namespace name; do
    kubectl patch application "$name" -n "$namespace" -p '{"metadata":{"finalizers":null}}' --type=merge
  done

# Delete CRDs
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io imageupdaters.argocd-image-updater.argoproj.io
```

