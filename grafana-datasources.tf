# O sidecar de datasources do Grafana varre ConfigMaps com este label e os
# carrega sozinho. Registrar por ConfigMap, em vez de alterar os values do
# kube-prometheus-stack, mantem cada sinal no seu proprio arquivo.
resource "kubernetes_config_map_v1" "grafana_datasource_loki" {
  metadata {
    name      = "grafana-datasource-loki"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name

    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki.yaml" = yamlencode({
      apiVersion = 1
      datasources = [{
        name      = "Loki"
        type      = "loki"
        access    = "proxy"
        url       = "http://loki:3100"
        isDefault = false
      }]
    })
  }

  depends_on = [helm_release.loki]
}
