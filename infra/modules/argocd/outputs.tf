output "namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
}

output "argocd_server_admin_password" {
  description = "Initial admin password for ArgoCD"
  value       = try(data.kubernetes_secret_v1.argocd_initial_admin_secret.data["password"], "")
  sensitive   = true
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.argocd.name
}
