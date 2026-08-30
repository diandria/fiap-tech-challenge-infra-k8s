# Loki em modo monolitico (SingleBinary): o ambiente tem dois nos e volume de
# log de demonstracao. O modo distribuido traria ingester, distributor,
# querier e compactor separados, sem ganho aqui e com custo de memoria que a
# conta do cluster nao comporta.
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

      # Armazenamento em disco do proprio pod. S3 seria o padrao em producao,
      # mas exigiria credencial de bucket no cluster e nao ha IRSA aqui.
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
        # Retencao de 7 dias: cobre a janela de demonstracao sem encher o disco.
        retention_period = "168h"

        # Trava de cardinalidade. Se alguem promover trace_id a label por
        # engano, o Loki recusa em vez de degradar silenciosamente.
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

    # Componentes do modo distribuido, desligados explicitamente.
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

    # O chart sobe um cache em memoria por padrao; desnecessario neste volume
    # e caro para a conta de memoria.
    chunksCache  = { enabled = false }
    resultsCache = { enabled = false }

    # Gateway nginx na frente do Loki: nao ha necessidade com um unico
    # consumidor (o Grafana), que fala direto com o Service.
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
          # 1. Desembrulha o formato do runtime. Sem isto, a linha inteira do
          #    CRI vira o "log" e o JSON da aplicacao nunca e alcancado.
          { cri = {} },

          # 2. Le o JSON que a aplicacao emite desde o M2.
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

          # 3. Promove a label apenas o que tem cardinalidade baixa.
          #
          #    trace_id fica de fora de proposito, e essa e a decisao desta
          #    tarefa: como label, cada requisicao criaria uma stream nova e o
          #    Loki degradaria rapido. Ele continua no corpo do log e e
          #    pesquisavel por filtro de linha:
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
