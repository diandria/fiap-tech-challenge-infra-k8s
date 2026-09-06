# Dashboards as code.
#
# A panel built in the Grafana UI is lost when the cluster is destroyed, and
# here the cluster is destroyed by design. Versioning the JSON is what makes the
# panel survive a teardown.
#
# Grafana's dashboard sidecar scans ConfigMaps labelled `grafana_dashboard = "1"`
# in every namespace and loads them on its own. There is no manual import step.
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
