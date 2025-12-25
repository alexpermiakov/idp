data "aws_caller_identity" "current" {}

locals {
  ecr_account_id = var.ecr_account_id
  cluster_name   = var.cluster_name
}

# IAM policy for ECR access
resource "aws_iam_policy" "ecr_pull" {
  name        = "${local.cluster_name}-ecr-pull-policy"
  description = "Policy for pulling images from ECR in account ${local.ecr_account_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:*:${local.ecr_account_id}:repository/*"
      }
    ]
  })
}

# IAM role for pod identity
resource "aws_iam_role" "ecr_pull" {
  name = "${local.cluster_name}-ecr-pull-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.ecr_pull.name
  policy_arn = aws_iam_policy.ecr_pull.arn
}

# Pod Identity Associations for dev environment only
# Note: When staging/prod clusters are created, they will have their own 
# instances of this module with their own pod identity associations

resource "aws_eks_pod_identity_association" "version_service_dev" {
  cluster_name    = local.cluster_name
  namespace       = "version-service-dev"
  service_account = "version-service"
  role_arn        = aws_iam_role.ecr_pull.arn
}

resource "aws_eks_pod_identity_association" "time_service_dev" {
  cluster_name    = local.cluster_name
  namespace       = "time-service-dev"
  service_account = "time-service"
  role_arn        = aws_iam_role.ecr_pull.arn
}
