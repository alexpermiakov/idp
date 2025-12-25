terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Get cluster info
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# IAM role for ECR access
resource "aws_iam_role" "ecr_pull" {
  name = "${var.cluster_name}-ecr-pull-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}

# IAM policy for ECR
resource "aws_iam_role_policy" "ecr_pull" {
  name = "ecr-pull-policy"
  role = aws_iam_role.ecr_pull.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:*:${var.ecr_account_id}:repository/*"
      }
    ]
  })
}

# Pod Identity Association for time-service-dev
resource "aws_eks_pod_identity_association" "time_service_dev" {
  cluster_name    = var.cluster_name
  namespace       = "time-service-dev"
  service_account = "time-service"
  role_arn        = aws_iam_role.ecr_pull.arn
}

# Pod Identity Association for version-service-dev
resource "aws_eks_pod_identity_association" "version_service_dev" {
  cluster_name    = var.cluster_name
  namespace       = "version-service-dev"
  service_account = "version-service"
  role_arn        = aws_iam_role.ecr_pull.arn
}
