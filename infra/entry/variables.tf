variable "pr_number" {
  description = "The pull request number"
  type        = number
}

variable "admin_role_arns" {
  description = "List of IAM role ARNs to grant admin access. Leave empty when creating locally."
  type        = list(string)
  default     = []
}

variable "target_branch" {
  description = "Git branch for ArgoCD to watch (e.g., main, feature/my-feature)"
  type        = string
  default     = "main"
}
