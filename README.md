# Internal Developer Platform

Infrastructure as Code for provisioning EKS clusters with ArgoCD.

## Local Development

### Prerequisites

Visit https://d-9267ef45c3.awsapps.com/start, click "Access keys", and copy the credentials.

```bash
# Test access
aws sts get-caller-identity
```

### Connect to EKS Cluster

After deployment:

```bash
export AWS_PROFILE=935743309409_AdministratorAccess

# Verify AWS access
aws sts get-caller-identity

# Update kubeconfig - replace <PR> with your PR number
aws eks update-kubeconfig --region us-west-2 --name k8s-pr-<PR>

# Verify connection
kubectl get nodes
```

### Access ArgoCD Dashboard

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# Port-forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
```

Access at http://localhost:8080 and login with username `admin` and the password from above.

