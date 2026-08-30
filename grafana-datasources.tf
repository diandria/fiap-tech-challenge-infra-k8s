# O sidecar de datasources do Grafana varre ConfigMaps com este label e os
# carrega sozinho.
#
# UIDs fixos de proposito: os dois datasources se referenciam um ao outro para
# a navegacao entre log e trace, e UID gerado nao daria para escrever aqui.
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

      # O Grafana persiste datasources no banco dele, que tem volume. Um
      # registro criado antes com UID gerado automaticamente faz o
      # provisionamento falhar com "data source not found", porque ele tenta
      # atualizar pelo UID declarado aqui e nao encontra.
      # deleteDatasources roda antes da insercao e resolve o conflito.
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
            # A ida: extrai trace_id do corpo do log e oferece um link para o
            # trace correspondente no Tempo.
            #
            # Sem isto, o Tempo fica instalado e inutil na pratica: ninguem
            # descobre o id de um trace lendo log a olho nu para colar na busca.
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
            # A volta: de um span, buscar as linhas de log daquela requisicao.
            tracesToLogsV2 = {
              datasourceUid = local.loki_datasource_uid

              # Janela em torno do span. Sem folga, log gravado alguns
              # milissegundos antes ou depois do span fica de fora.
              spanStartTimeShift = "-5m"
              spanEndTimeShift   = "5m"

              # Filtra pelo trace_id no corpo, nao por label -- coerente com a
              # decisao de cardinalidade do PR anterior.
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
