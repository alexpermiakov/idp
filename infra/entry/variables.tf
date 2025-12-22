variable "pr_number" {
  description = "The pull request number"
  type        = number
}

variable "admin_role_arns" {
  description = "List of IAM role ARNs to grant admin access. Leave empty when creating locally."
  type        = list(string)
  default     = []
}
