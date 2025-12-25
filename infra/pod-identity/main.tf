terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-alexidp-dev"
    key    = "pod-identity/state.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

module "ecr_pod_identity" {
  source = "../modules/ecr-pod-identity"

  cluster_name   = "k8s-pr-7"
  ecr_account_id = "864992049050"
}
