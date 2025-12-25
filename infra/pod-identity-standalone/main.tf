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

module "ecr_pod_identity" {
  source = "../modules/ecr-pod-identity"

  cluster_name   = var.cluster_name
  ecr_account_id = var.ecr_account_id
}
