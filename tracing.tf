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

      # 1Gi, not 512Mi: with the previous limit Tempo was OOMKilled on startup
      # in a loop, 8 restarts in 56 minutes, never becoming ready. The CD failed
      # waiting for observability, and the application's spans were dropped
      # silently, with nothing in its log indicating loss.
      resources = {
        requests = { memory = "512Mi", cpu = "100m" }
        limits   = { memory = "1Gi" }
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
