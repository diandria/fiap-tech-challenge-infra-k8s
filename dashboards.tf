# Dashboards como codigo.
#
# Painel montado pela UI do Grafana se perde quando o cluster e destruido, e
# aqui o cluster e destruido por construcao -- o ambiente e efemero. Versionar
# o JSON e o que faz o painel sobreviver ao teardown.
#
# O sidecar de dashboards do Grafana varre ConfigMaps com o label
# `grafana_dashboard = "1"` em todos os namespaces e os carrega sozinho. Nao ha
# passo manual de importacao.
locals {
  dashboards = fileset("${path.module}/dashboards", "*.json")
}

resource "kubernetes_config_map_v1" "dashboards" {
  for_each = local.dashboards

  metadata {
    name      = "grafana-dashboard-${trimsuffix(each.value, ".json")}"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name

    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    (each.value) = file("${path.module}/dashboards/${each.value}")
  }
}
