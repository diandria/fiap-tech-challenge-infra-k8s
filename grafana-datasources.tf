# Grafana's datasource sidecar scans ConfigMaps with this label and loads them
# on its own.
#
# Fixed UIDs on purpose: the two datasources reference each other for the
# log-to-trace navigation, and a generated UID could not be written here.
locals {
  loki_datasource_uid  = "loki"
  tempo_datasource_uid = "tempo"
}

resource "kubernetes_config_map_v1" "grafana_datasource_logs_traces" {
  metadata {
    name      = "grafana-datasource-logs-traces"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name

    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "logs-traces.yaml" = yamlencode({
      apiVersion = 1

      # Grafana persists datasources in its own database, which has a volume. A
      # record created earlier with a generated UID makes provisioning fail with
      # "data source not found", because it updates by the UID declared here.
      # deleteDatasources runs before the insert and resolves the conflict.
      deleteDatasources = [
        { name = "Loki", orgId = 1 },
        { name = "Tempo", orgId = 1 },
      ]

      datasources = [
        {
          name      = "Loki"
          type      = "loki"
          uid       = local.loki_datasource_uid
          access    = "proxy"
          url       = "http://loki:3100"
          isDefault = false

          jsonData = {
            # The outbound path: extracts trace_id from the log body and offers
            # a link to the matching trace in Tempo. Without it Tempo is
            # installed but unusable in practice.
            derivedFields = [{
              name            = "trace_id"
              matcherType     = "label"
              matcherRegex    = "trace_id"
              url             = "$${__value.raw}"
              datasourceUid   = local.tempo_datasource_uid
              urlDisplayLabel = "Ver trace"
            }]
          }
        },
        {
          name      = "Tempo"
          type      = "tempo"
          uid       = local.tempo_datasource_uid
          access    = "proxy"
          url       = "http://tempo:3100"
          isDefault = false

          jsonData = {
            # The return path: from a span, find that request's log lines.
            tracesToLogsV2 = {
              datasourceUid = local.loki_datasource_uid

              # Window around the span. Without slack, a line written a few
              # milliseconds before or after the span falls outside it.
              spanStartTimeShift = "-5m"
              spanEndTimeShift   = "5m"

              # Filters by trace_id in the body, not by label, consistent with
              # the cardinality decision in logs.tf.
              filterByTraceID = true
              customQuery     = true
              query           = "{$${__tags}} | json | trace_id=`$${__span.traceId}`"

              tags = [{ key = "service.name", value = "service_name" }]
            }

            serviceMap = { datasourceUid = "prometheus" }
          }
        },
      ]
    })
  }

  depends_on = [
    helm_release.loki,
    helm_release.tempo,
  ]
}
