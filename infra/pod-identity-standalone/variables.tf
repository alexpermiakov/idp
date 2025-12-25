variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "ecr_account_id" {
  description = "AWS account ID where ECR repositories are located"
  type        = string
  default     = "864992049050"
}
