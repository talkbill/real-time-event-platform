resource "kubernetes_namespace_v1" "redis" {
  metadata {
    name   = "redis"
    labels = { "app.kubernetes.io/managed-by" = "terraform" }
  }
}

resource "helm_release" "redis" {
  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  namespace  = kubernetes_namespace_v1.redis.metadata[0].name
  version    = "20.6.1"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    architecture = "standalone"

    image = {
      registry   = "docker.io"
      repository = "redis"
      tag        = "7.2-alpine"
      pullPolicy = "IfNotPresent"
    }

    sysctlImage = {
      enabled = false
    }

    auth = {
      enabled = false
    }

    master = {
      persistence = {
        enabled = false
      }
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { cpu = "250m", memory = "256Mi" }
      }
    }
  })]

  depends_on = [kubernetes_namespace_v1.redis]
}