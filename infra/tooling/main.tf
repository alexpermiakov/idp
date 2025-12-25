terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_ecr_repository" "localtime" {
  name                 = "idp/localtime"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "IDP LocalTime Service"
  }
}

resource "aws_ecr_repository" "version" {
  name                 = "idp/version"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "IDP Version Service"
  }
}

resource "aws_ecr_repository_policy" "allow_dev_pull" {
  repository = aws_ecr_repository.localtime.name

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
  repository = aws_ecr_repository.version.name

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
