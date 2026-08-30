locals {
  cluster_name = "car-repair-shop"

  # Namespace unico para toda a observabilidade: Prometheus, Grafana, Loki e
  # Tempo. Facilita aplicar limite de recurso e apagar tudo de uma vez.
  observability_namespace = "observability"

  # Namespace e nome do Service da aplicacao. O deploy dos pods vem no M8, mas
  # o Service nasce aqui porque ele e a origem do NLB.
  app_namespace    = "car-repair-shop"
  app_service_name = "car-repair-shop-api"
}
