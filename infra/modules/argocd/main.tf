resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "9.1.9"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  set = [
    {
      name  = "server.service.type"
      value = "ClusterIP"
    },
    {
      name  = "server.extraArgs[0]"
      value = "--insecure"
    },
    {
      # Enable admin user
      name  = "configs.params.server\\.insecure"
      value = "true"
    }
  ]

  depends_on = [kubernetes_namespace_v1.argocd]
}

resource "helm_release" "argocd_image_updater" {
  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = "1.0.2"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  set = [
    {
      name  = "config.registries[0].name"
      value = "ECR"
    },
    {
      name  = "config.registries[0].api_url"
      value = "https://864992049050.dkr.ecr.us-east-1.amazonaws.com"
    },
    {
      name  = "config.registries[0].prefix"
      value = "864992049050.dkr.ecr.us-east-1.amazonaws.com"
    },
    {
      name  = "config.registries[0].ping"
      value = "no"
    },
    {
      name  = "config.argocd.grpcWeb"
      value = "true"
    },
    {
      name  = "config.argocd.insecure"
      value = "true"
    },
    {
      name  = "config.argocd.plaintext"
      value = "true"
    },
    {
      name  = "config.gitCommitUser"
      value = "argocd-image-updater[bot]"
    },
    {
      name  = "config.gitCommitMail"
      value = "argocd-image-updater[bot]@users.noreply.github.com"
    }
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.github_app_credentials
  ]
}

resource "kubernetes_secret_v1" "github_app_credentials" {
  count = var.github_app_id != "" ? 1 : 0

  metadata {
    name      = "github-app-credentials"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type                    = "git"
    url                     = "https://github.com/alexpermiakov/idp"
    githubAppID             = var.github_app_id
    githubAppInstallationID = var.github_app_installation_id
    githubAppPrivateKey     = var.github_app_private_key
  }

  depends_on = [helm_release.argocd]
}

# Get the initial admin password
data "kubernetes_secret_v1" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}

# Apply the app-of-apps pattern to bootstrap ArgoCD applications
resource "null_resource" "app_of_apps" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${var.cluster_name} --region us-west-2
      kubectl apply -f ${path.root}/../../argocd/applicationset.yaml
    EOT
  }

  depends_on = [helm_release.argocd]

  triggers = {
    manifest_sha = filesha256("${path.root}/../../argocd/applicationset.yaml")
  }
}
