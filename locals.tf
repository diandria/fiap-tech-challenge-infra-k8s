locals {
  cluster_name = "car-repair-shop"

  # One namespace for all observability: Prometheus, Grafana, Loki and Tempo.
  # It makes resource limits and a single teardown straightforward.
  observability_namespace = "observability"

  # Application namespace and the name of its Service. The Service itself is
  # declared in the application repository; the name lives here because the
  # tag-based NLB lookup depends on it.
  app_namespace    = "car-repair-shop"
  app_service_name = "car-repair-shop-api"
}
