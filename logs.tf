# Loki in monolithic mode (SingleBinary): two nodes and a demonstration log
# volume. Distributed mode would bring separate ingester, distributor, querier
# and compactor, with no gain here and a memory cost the cluster cannot absorb.
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "7.3.0"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  timeout    = 900

  values = [yamlencode({
    deploymentMode = "SingleBinary"

    loki = {
      auth_enabled = false

      commonConfig = { replication_factor = 1 }

      # Storage on the pod's own disk. S3 would be the production default but
      # would need bucket credentials in the cluster, and there is no IRSA here.
      storage = { type = "filesystem" }

      schemaConfig = {
        configs = [{
          from         = "2024-04-01"
          store        = "tsdb"
          object_store = "filesystem"
          schema       = "v13"
          index        = { prefix = "index_", period = "24h" }
        }]
      }

      limits_config = {
        # Seven days: covers the demonstration window without filling the disk.
        retention_period = "168h"

        # Cardinality guard. If trace_id is promoted to a label by mistake, Loki
        # refuses instead of degrading silently.
        max_label_names_per_series = 15
      }
    }

    singleBinary = {
      replicas = 1
      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi" }
      }
      persistence = {
        enabled      = true
        storageClass = "gp3"
        size         = "10Gi"
      }
    }

    # Distributed-mode components, explicitly disabled.
    backend        = { replicas = 0 }
    read           = { replicas = 0 }
    write          = { replicas = 0 }
    ingester       = { replicas = 0 }
    querier        = { replicas = 0 }
    queryFrontend  = { replicas = 0 }
    distributor    = { replicas = 0 }
    compactor      = { replicas = 0 }
    indexGateway   = { replicas = 0 }
    bloomCompactor = { replicas = 0 }
    bloomGateway   = { replicas = 0 }

    # The chart runs an in-memory cache by default: unnecessary at this volume
    # and costly for the memory budget.
    chunksCache  = { enabled = false }
    resultsCache = { enabled = false }

    # An nginx gateway in front of Loki is unnecessary with a single consumer,
    # Grafana, which talks to the Service directly.
    gateway = { enabled = false }

    test       = { enabled = false }
    lokiCanary = { enabled = false }
  })]

  depends_on = [
    kubernetes_storage_class_v1.gp3,
    helm_release.kube_prometheus_stack,
  ]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.17.1"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  timeout    = 600

  values = [yamlencode({
    config = {
      clients = [{
        url = "http://loki:3100/loki/api/v1/push"
      }]

      snippets = {
        pipelineStages = [
          # 1. Unwraps the runtime format. Without it the whole CRI line becomes
          #    the "log" and the application JSON is never reached.
          { cri = {} },

          # 2. Reads the JSON the application emits.
          {
            json = {
              expressions = {
                level        = "level"
                service_name = "service_name"
                route        = "route"
                statusCode   = "statusCode"
                trace_id     = "trace_id"
              }
            }
          },

          # 3. Promotes to labels only what has low cardinality.
          #
          #    trace_id stays out on purpose: as a label, every request would
          #    create a new stream and Loki would degrade quickly. It remains in
          #    the log body and is searchable by line filter:
          #      {service_name="car-repair-shop-api"} | json | trace_id="..."
          {
            labels = {
              level        = null
              service_name = null
              route        = null
              statusCode   = null
            }
          },
        ]
      }
    }

    resources = {
      requests = { memory = "96Mi", cpu = "50m" }
      limits   = { memory = "192Mi" }
    }
  })]

  depends_on = [helm_release.loki]
}
