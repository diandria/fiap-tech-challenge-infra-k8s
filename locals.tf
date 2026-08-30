locals {
  cluster_name = "car-repair-shop"

  # Namespace unico para toda a observabilidade: Prometheus, Grafana, Loki e
  # Tempo. Facilita aplicar limite de recurso e apagar tudo de uma vez.
  observability_namespace = "observability"
}
