terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-alexidp-tooling"
    key    = "ecr/state.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_ecr_repository_policy" "allow_dev_pull" {
  repository = "idp/localtime"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDevAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::935743309409:root",
            # Add staging and prod account ARNs when ready
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "allow_dev_pull_version" {
  repository = "idp/version"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDevAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::935743309409:root",
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
