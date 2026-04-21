resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name   = "argocd"
    labels = { "app.kubernetes.io/managed-by" = "terraform" }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  version    = "7.4.4"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    server = {
      service = {
        type = "ClusterIP"
      }
    }
    configs = {
      params = {
        "server.insecure" = true
      }
    }
  })]

  depends_on = [kubernetes_namespace_v1.argocd]
}

# The ArgoCD Application resource tells ArgoCD what repo to watch,
resource "kubectl_manifest" "argocd_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: real-time-platform
      namespace: argocd
      # Finalizer ensures ArgoCD deletes cluster resources when
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: https://github.com/${var.github_org}/${var.github_repo}
        targetRevision: main
        path: kubernetes/overlays/dev
      destination:
        server: https://kubernetes.default.svc
        namespace: real-time-platform
      syncPolicy:
        automated:
          prune: true 
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}