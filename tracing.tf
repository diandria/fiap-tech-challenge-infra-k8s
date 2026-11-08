# Tempo as a single binary, same reason as Loki: two nodes and a demonstration
# volume do not justify distributed mode.
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.24.4"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  timeout    = 600

  values = [yamlencode({
    tempo = {
      # The application exports OTLP over HTTP on 4318. The receiver has to
      # match its OTEL_EXPORTER_OTLP_ENDPOINT.
      receivers = {
        otlp = {
          protocols = {
            http = { endpoint = "0.0.0.0:4318" }
            grpc = { endpoint = "0.0.0.0:4317" }
          }
        }
      }

      retention = "168h"

      # 2Gi: with 512Mi Tempo was OOMKilled on startup, and with 1Gi it was
      # OOMKilled compacting the blocks of a five-minute load test, in a loop,
      # so the traces disappeared exactly when there was traffic to look at.
      # Each loss is silent: the services keep exporting spans and log nothing.
      # The nodes have the room: a t3.large gives 7Gi, and the cluster uses
      # under half of it after a load test.
      resources = {
        requests = { memory = "1Gi", cpu = "100m" }
        limits   = { memory = "2Gi" }
      }
    }

    persistence = {
      enabled          = true
      storageClassName = "gp3"
      size             = "10Gi"
    }
  })]

  depends_on = [
    kubernetes_storage_class_v1.gp3,
    helm_release.loki,
  ]
}
