variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID for ArgoCD Image Updater"
  type        = string
  default     = ""
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  default     = ""
}

variable "github_app_private_key" {
  description = "GitHub App private key (PEM format)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "target_branch" {
  description = "Git branch for ArgoCD to watch (e.g., main, feature/my-feature)"
  type        = string
  default     = "main"
}
