# Traz de uma vez Prometheus Operator, Prometheus, Alertmanager, Grafana,
# kube-state-metrics e node-exporter. Os dois ultimos sao o que atende
# "consumo de recursos do Kubernetes" sem escrever instrumentacao.
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "88.6.1"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name

  # Charts desta stack criam muitos CRDs e recursos; 15 minutos evita falso
  # negativo por tempo esgotado num cluster de dois nos.
  timeout = 900

  values = [yamlencode({
    # Requests explicitos em todo componente: com 6,43 GiB alocaveis medidos,
    # o agendador precisa saber o custo real de cada peca para nao aceitar
    # mais carga do que cabe.
    prometheus = {
      prometheusSpec = {
        # Ambiente efemero: reter mais que um dia so gasta disco.
        retention = "24h"

        resources = {
          requests = { memory = "512Mi", cpu = "150m" }
          limits   = { memory = "1Gi" }
        }

        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "gp3"
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = "10Gi" } }
            }
          }
        }

        # Sem isto o Prometheus so enxerga ServiceMonitors com o label do
        # proprio release, e os da aplicacao (M8) seriam ignorados em silencio.
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
      }

      # PodMonitor, e nao ServiceMonitor: a porta do Service da aplicacao nao
      # tem nome, e um ServiceMonitor seleciona a porta pelo nome. Nomear a
      # porta significaria alterar o Service que sustenta o NLB de que o API
      # Gateway depende -- risco desproporcional para uma questao de coleta. A
      # porta do container ja se chama `http`, e o PodMonitor usa essa.
      #
      # Declarado como valor do chart, e nao como kubernetes_manifest: o CRD
      # PodMonitor so passa a existir depois que este mesmo Helm release e
      # aplicado, e um kubernetes_manifest exigiria o CRD ja presente no
      # `plan`. Numa subida do zero isso falha antes de criar qualquer coisa.
      additionalPodMonitors = [
        {
          name = "car-repair-shop"

          # A aplicacao vive em outro namespace. Sem isto o Prometheus procura
          # so no proprio, nao encontra nada, e nao reporta erro: o alvo
          # simplesmente nao aparece, e o sintoma e dashboard vazio.
          namespaceSelector = { matchNames = [local.app_namespace] }
          selector          = { matchLabels = { app = local.app_service_name } }

          podMetricsEndpoints = [
            {
              port     = "http"
              path     = "/metrics"
              interval = "15s"
            }
          ]
        }
      ]
    }

    alertmanager = {
      alertmanagerSpec = {
        resources = {
          requests = { memory = "96Mi", cpu = "25m" }
          limits   = { memory = "192Mi" }
        }
      }
    }

    grafana = {
      # A senha vem do Secret, nunca daqui.
      admin = {
        existingSecret = "grafana-admin"
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }

      # ClusterIP de proposito: o acesso na demonstracao e por
      # kubectl port-forward. Expor o Grafana criaria um segundo caminho de
      # entrada, fora do API Gateway.
      service = { type = "ClusterIP" }

      resources = {
        requests = { memory = "192Mi", cpu = "50m" }
        limits   = { memory = "384Mi" }
      }

      persistence = {
        enabled          = true
        storageClassName = "gp3"
        size             = "2Gi"
      }

      # O pod do Grafana tem tres containers: o principal e dois sidecars que
      # sincronizam dashboards e datasources. O bloco resources acima so
      # alcanca o principal; sem isto os sidecars ficam sem teto, e a conta de
      # memoria do cluster deixa de fechar.
      sidecar = {
        resources = {
          requests = { memory = "48Mi", cpu = "10m" }
          limits   = { memory = "96Mi" }
        }
      }
    }

    prometheusOperator = {
      resources = {
        requests = { memory = "128Mi", cpu = "50m" }
        limits   = { memory = "256Mi" }
      }
    }

    kube-state-metrics = {
      resources = {
        requests = { memory = "96Mi", cpu = "25m" }
        limits   = { memory = "192Mi" }
      }
    }

    prometheus-node-exporter = {
      resources = {
        requests = { memory = "48Mi", cpu = "25m" }
        limits   = { memory = "96Mi" }
      }
    }

    # O EKS nao expoe estes componentes do control plane: deixar habilitado
    # gera alerta permanente de target inalcancavel, que treina quem olha o
    # painel a ignorar alerta vermelho.
    kubeEtcd              = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeProxy             = { enabled = false }
  })]

  depends_on = [
    kubernetes_secret_v1.grafana_admin,
    kubernetes_storage_class_v1.gp3,
    helm_release.aws_load_balancer_controller,
  ]
}
