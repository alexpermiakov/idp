variable "pr_number" {
  description = "The pull request number"
  type        = number
}

variable "vpc_id" {
  description = "The VPC ID where the resources will be deployed"
  type        = string
}

variable "vpc_subnet_ids" {
  description = "The subnet IDs within the VPC"
  type        = list(string)
}

variable "cicd_role_arn" {
  description = "ARN of the CI/CD role (e.g., GitHub Actions) that needs cluster access"
  type        = string
  default     = ""
}
