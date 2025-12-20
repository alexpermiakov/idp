output "cluster_token" {
  description = "Token for cluster authentication"
  value       = data.aws_eks_cluster_auth.this.token
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = module.eks.cluster_id
}
