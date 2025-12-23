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
