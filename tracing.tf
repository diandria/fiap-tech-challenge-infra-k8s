# Tempo em binario unico, mesma razao do Loki: dois nos e volume de
# demonstracao nao justificam o modo distribuido.
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.24.4"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  timeout    = 600

  values = [yamlencode({
    tempo = {
      # A aplicacao exporta OTLP por HTTP na 4318 desde o M3.T6. O receptor
      # precisa casar com o OTEL_EXPORTER_OTLP_ENDPOINT dela.
      receivers = {
        otlp = {
          protocols = {
            http = { endpoint = "0.0.0.0:4318" }
            grpc = { endpoint = "0.0.0.0:4317" }
          }
        }
      }

      retention = "168h"

      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi" }
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
