resource "kubernetes_namespace_v1" "kafka" {
  metadata {
    name   = "kafka"
    labels = { "app.kubernetes.io/managed-by" = "terraform" }
  }
}

resource "helm_release" "strimzi" {
  name       = "strimzi"
  repository = "https://strimzi.io/charts"
  chart      = "strimzi-kafka-operator"
  namespace  = kubernetes_namespace_v1.kafka.metadata[0].name
  version    = "0.43.0"

  values     = ["watchNamespaces: [\"kafka\"]"]
  depends_on = [kubernetes_namespace_v1.kafka]
}

resource "kubernetes_manifest" "kafka_cluster" {

  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "Kafka"
    metadata = {
      name      = "event-cluster"
      namespace = kubernetes_namespace_v1.kafka.metadata[0].name
    }
    spec = {
      kafka = {
        version  = var.kafka_version
        replicas = 3
        listeners = [
          {
            name = "plain"
            port = 9092
            type = "internal"
            tls = false
          },
          { 
            name = "external"
            port = 9094
            type = "loadbalancer"
            tls = false
          }
        ]
        config = {
          "offsets.topic.replication.factor"         = 3
          "transaction.state.log.replication.factor" = 3
          "transaction.state.log.min.isr"            = 2
          "default.replication.factor"               = 3
          "min.insync.replicas"                      = 2
        }
        storage = { type = "ephemeral" }
      }
      zookeeper = {
        replicas = 3
        storage  = { type = "ephemeral" }
      }
      entityOperator = {
        topicOperator = {}
        userOperator  = {}
      }
    }
  }
  depends_on = [helm_release.strimzi]
}

resource "kubernetes_manifest" "kafka_topic" {

  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaTopic"
    metadata = {
      name      = "user-events"
      namespace = kubernetes_namespace_v1.kafka.metadata[0].name
      labels    = { "strimzi.io/cluster" = "event-cluster" }
    }
    spec = {
      partitions = 10
      replicas   = 3
      config = {
        "retention.ms"   = 604800000
        "segment.bytes"  = 1073741824
      }
    }
  }
  depends_on = [kubernetes_manifest.kafka_cluster]
}
