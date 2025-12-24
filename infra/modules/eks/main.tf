locals {
  cluster_name = "k8s-pr-${var.pr_number}"
}

resource "aws_iam_role" "eks_worker_node_role" {
  name = "${local.cluster_name}-worker-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  role       = aws_iam_role.eks_worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.1"

  name               = local.cluster_name
  kubernetes_version = "1.34"

  vpc_id     = var.vpc_id
  subnet_ids = var.vpc_subnet_ids

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    example = {
      instance_types = ["t3.medium"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  tags = {
    Name = "k8s-cluster-pr-${var.pr_number}"
    PR   = var.pr_number
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "admin_roles" {
  for_each = toset(var.admin_role_arns)

  cluster_name      = module.eks.cluster_name
  principal_arn     = each.value
  type              = "STANDARD"
  kubernetes_groups = ["eks-admins"]
}

resource "time_sleep" "wait_for_cluster_ready" {
  depends_on = [
    module.eks,
    aws_eks_access_entry.admin_roles,
  ]

  create_duration = "30s"
}

resource "kubernetes_cluster_role_binding_v1" "eks_admins" {
  metadata {
    name = "eks-admins-clusterrolebinding"
  }

  subject {
    kind      = "Group"
    name      = "eks-admins"
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin" # Use built-in cluster-admin role for full access
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [time_sleep.wait_for_cluster_ready]
}
