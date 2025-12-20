terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = "us-west-2"
}

module "vpc" {
  source    = "../modules/vpc"
  pr_number = var.pr_number

  vpc_cidr_block     = "10.0.0.0/16"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

module "eks" {
  source    = "../modules/eks"
  pr_number = var.pr_number

  vpc_id         = module.vpc.vpc_id
  vpc_subnet_ids = module.vpc.private_subnet_ids
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = module.eks.cluster_token
}
