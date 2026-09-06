# Brings Prometheus Operator, Prometheus, Alertmanager, Grafana,
# kube-state-metrics and node-exporter in one release. The last two cover
# Kubernetes resource usage without writing any instrumentation.
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "88.6.1"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name

  # This stack creates many CRDs and resources; 15 minutes avoids a false
  # negative from a timeout on a two-node cluster.
  timeout = 900

  values = [yamlencode({
    # Explicit requests on every component: with 6.43 GiB measured allocatable,
    # the scheduler needs each piece's real cost so it does not accept more load
    # than fits.
    #
    # Alerts for service order processing failures. What counts as a failure:
    # 5xx technical errors and integration failures. Business errors (4xx) stay
    # out, since those are the API correctly refusing an invalid operation, and
    # alerting on them trains the team to ignore alerts.
    #
    # Declared as a chart value rather than a kubernetes_manifest for the same
    # reason as the PodMonitor: the PrometheusRule CRD is born with this release.
    additionalPrometheusRulesMap = {
      car-repair-shop = {
        groups = [
          {
            name = "car-repair-shop"
            rules = [
              {
                alert = "ServiceOrderProcessingFailures"
                expr  = "sum(rate(integration_failures_total[5m])) > 0"

                # 1 minute rather than the 5 production would ask for: a long
                # `for` means minutes of blank screen during a demonstration.
                # Shortened on purpose, and noted in the alert itself.
                for    = "1m"
                labels = { severity = "critical" }
                annotations = {
                  summary     = "Falhas de integracao no processamento de ordens de servico"
                  description = "A integracao {{ $labels.integration }} falhou na operacao {{ $labels.operation }}. As notificacoes sao best-effort e os casos de uso engolem o erro de proposito, entao este contador e o unico sinal."
                  janela      = "for=1m encurtado para demonstracao; em producao seria 5m"
                }
              },
              {
                alert  = "ApplicationDown"
                expr   = "(sum(up{job=\"observability/car-repair-shop\"}) or vector(0)) == 0"
                for    = "1m"
                labels = { severity = "critical" }
                annotations = {
                  summary     = "Aplicacao fora do ar"
                  description = "Nenhum alvo da aplicacao esta respondendo ao scrape."

                  # `up == 0` alone misses the likeliest case. If the pods
                  # disappear the PodMonitor finds no target, the series stops
                  # existing, and an expression over a missing series yields
                  # nothing: the alert stays silent exactly when it should fire.
                  # `or vector(0)` gives absence a value.
                  nota = "a ausencia de serie conta como fora do ar, nao so o scrape falhando"
                }
              },
              {
                alert  = "HighErrorRate"
                expr   = "sum(rate(http_request_duration_seconds_count{status_code=~\"5..\"}[5m])) / clamp_min(sum(rate(http_request_duration_seconds_count[5m])), 0.001) > 0.05"
                for    = "2m"
                labels = { severity = "critical" }
                annotations = {
                  summary     = "Mais de 5% das requisicoes respondendo 5xx"
                  description = "Proporcao de erro tecnico acima do limite por 2 minutos."
                }
              },
              {
                alert  = "HighApiLatency"
                expr   = "histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m]))) > 1"
                for    = "5m"
                labels = { severity = "warning" }
                annotations = {
                  summary     = "p95 de latencia acima de 1 segundo"
                  description = "O percentil 95 das requisicoes passou de 1s por 5 minutos."
                }
              },
            ]
          }
        ]
      }
    }

    prometheus = {
      prometheusSpec = {
        # Ephemeral environment: retaining more than a day only wastes disk.
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

        # Without this Prometheus only sees ServiceMonitors carrying its own
        # release label, and the application's would be ignored silently.
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
      }

      # PodMonitor, not ServiceMonitor: the application Service's port has no
      # name, and a ServiceMonitor selects the port by name. Naming it would
      # mean changing the Service that anchors the NLB the gateway depends on.
      # The container port is already called `http`, so the PodMonitor uses it.
      #
      # A chart value rather than a kubernetes_manifest: the PodMonitor CRD only
      # exists after this Helm release is applied, and a kubernetes_manifest
      # would require the CRD present at plan time.
      additionalPodMonitors = [
        {
          name = "car-repair-shop"

          # The application lives in another namespace. Without this Prometheus
          # searches only its own, finds nothing and reports no error: the
          # target simply never appears and the dashboard is empty.
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
      # The password comes from the Secret, never from here.
      admin = {
        existingSecret = "grafana-admin"
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }

      # ClusterIP on purpose: access during the demonstration is by
      # kubectl port-forward. Exposing Grafana would create a second entry
      # point outside the API Gateway.
      service = { type = "ClusterIP" }

      # 384Mi was not enough: the container was OOMKilled with the five
      # dashboards loaded, and the crash drops the demonstration port-forward
      # with no symptom in Grafana, only "lost connection to pod" in kubectl.
      resources = {
        requests = { memory = "256Mi", cpu = "50m" }
        limits   = { memory = "768Mi" }
      }

      persistence = {
        enabled          = true
        storageClassName = "gp3"
        size             = "2Gi"
      }

      # The Grafana pod has three containers: the main one and two sidecars that
      # sync dashboards and datasources. The resources block above reaches only
      # the main one, so without this the sidecars have no ceiling.
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

    # EKS does not expose these control plane components: leaving them enabled
    # produces a permanent unreachable-target alert, which trains whoever reads
    # the panel to ignore red.
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
