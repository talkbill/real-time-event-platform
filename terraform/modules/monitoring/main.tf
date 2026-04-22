resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_stack_chart_version
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [yamlencode({
    grafana = {
      adminPassword = var.grafana_admin_password
      service = {
        type = "ClusterIP"
      }
      sidecar = {
        datasources = {
          defaultDatasourceEnabled = true
        }
        dashboards = {
          enabled = true
          label   = "grafana_dashboard"
        }
      }
      # Wire Loki in as an additional Grafana datasource
      additionalDataSources = [
        {
          name   = "Loki"
          type   = "loki"
          url    = "http://loki.monitoring:3100"
          access = "proxy"
        }
      ]
    }

    prometheus = {
      prometheusSpec = {
        retention = "7d"
        # Watch ServiceMonitors across all namespaces — required to scrape
        # real-time-platform without matching Helm's own labels
        serviceMonitorSelectorNilUsesHelmValues = false
      }
    }
  })]

  depends_on = [kubernetes_namespace_v1.monitoring]
}

# Loki in monolithic / SingleBinary mode with filesystem storage.
# Appropriate for dev — logs are lost on pod restart.
# Production path: switch storage.type to s3 and point at an S3 bucket.
resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = var.loki_chart_version
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
    deploymentMode = "SingleBinary"

    loki = {
      commonConfig = {
        replication_factor = 1
      }
      storage = {
        type = "filesystem"
      }
      schemaConfig = {
        configs = [
          {
            from         = "2024-04-01"
            store        = "tsdb"
            object_store = "filesystem"
            schema       = "v13"
            index = {
              prefix = "index_"
              period = "24h"
            }
          }
        ]
      }
      auth_enabled = false
    }

    singleBinary = {
      replicas = 1
    }

    # Zero out all scalable-mode components so they don't conflict
    # with SingleBinary mode
    read = {
      replicas = 0
    }
    write = {
      replicas = 0
    }
    backend = {
      replicas = 0
    }

    # Disable canary and monitoring subchart — we use kube-prometheus-stack
    lokiCanary = {
      enabled = false
    }
    monitoring = {
      selfMonitoring = {
        enabled = false
        grafanaAgent = {
          installOperator = false
        }
      }
    }

    gateway = {
      enabled = false
    }
  })]

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    helm_release.kube_prometheus_stack,
  ]
}

# Grafana Alloy — replacement for deprecated Promtail.
# Runs as a DaemonSet, collects pod logs and ships to Loki.
resource "helm_release" "alloy" {
  name             = "alloy"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "alloy"
  version          = var.alloy_chart_version
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  create_namespace = false
  wait             = false
  timeout          = 300

  values = [yamlencode({
    alloy = {
      configMap = {
        content = <<-ALLOY
          discovery.kubernetes "pods" {
            role = "pod"
          }

          discovery.relabel "pods" {
            targets = discovery.kubernetes.pods.targets

            rule {
              source_labels = ["__meta_kubernetes_pod_node_name"]
              target_label  = "__host__"
            }

            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              target_label  = "namespace"
            }

            rule {
              source_labels = ["__meta_kubernetes_pod_name"]
              target_label  = "pod"
            }

            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              target_label  = "container"
            }

            rule {
              source_labels = ["__meta_kubernetes_pod_label_app"]
              target_label  = "app"
            }
          }

          loki.source.kubernetes "pods" {
            targets    = discovery.relabel.pods.output
            forward_to = [loki.write.default.receiver]
          }

          loki.write "default" {
            endpoint {
              url = "http://loki.monitoring:3100/loki/api/v1/push"
            }
          }
        ALLOY
      }
    }

    controller = {
      type = "daemonset"
    }
  })]

  depends_on = [helm_release.loki]
}

# ServiceMonitor so Prometheus scrapes the api-gateway /metrics endpoint.
# Without this Prometheus runs but never collects your application metrics.
resource "kubectl_manifest" "api_gateway_service_monitor" {
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: api-gateway
      namespace: monitoring
      labels:
        release: kube-prometheus-stack
    spec:
      namespaceSelector:
        matchNames:
          - real-time-platform
      selector:
        matchLabels:
          app: api-gateway
      endpoints:
        - port: http
          path: /metrics
          interval: 30s
  YAML

  depends_on = [helm_release.kube_prometheus_stack]
}