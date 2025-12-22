output "argocd_server_admin_password" {
  description = "Initial admin password for ArgoCD"
  value       = module.argocd.argocd_server_admin_password
  sensitive   = true
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}
