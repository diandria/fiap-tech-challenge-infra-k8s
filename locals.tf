locals {
  cluster_name = "car-repair-shop"

  # Namespace unico para toda a observabilidade: Prometheus, Grafana, Loki e
  # Tempo. Facilita aplicar limite de recurso e apagar tudo de uma vez.
  observability_namespace = "observability"

  # Namespace da aplicacao e nome do seu Service. O Service em si e declarado no
  # repositorio da aplicacao; o nome fica aqui porque a busca do NLB por tag
  # depende dele.
  app_namespace    = "car-repair-shop"
  app_service_name = "car-repair-shop-api"
}
