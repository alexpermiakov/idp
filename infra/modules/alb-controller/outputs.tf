output "service_account_role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller service account"
  value       = aws_iam_role.lb_controller.arn
}

output "service_account_name" {
  description = "Name of the service account for AWS Load Balancer Controller"
  value       = local.lb_controller_service_account_name
}
