output "ecr_pull_role_arn" {
  description = "ARN of the IAM role for ECR pull access"
  value       = aws_iam_role.ecr_pull.arn
}
