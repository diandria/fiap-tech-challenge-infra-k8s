locals {
  cluster_name = "car-repair-shop"

  # One namespace for all observability: Prometheus, Grafana, Loki and Tempo.
  # It makes resource limits and a single teardown straightforward.
  observability_namespace = "observability"

  # The single source of each service's names: its namespace, the name of its
  # Kubernetes Service and its image registry. The Service itself is declared
  # in the service's repository; the name lives here because the tag-based NLB
  # lookup depends on it.
  services = {
    os = {
      namespace   = "car-repair-shop"
      k8s_service = "car-repair-shop-api"
      registry    = "car-repair-shop"
    }
    billing = {
      namespace   = "car-repair-shop-billing"
      k8s_service = "billing-api"
      registry    = "car-repair-shop-billing"
    }
    execution = {
      namespace   = "car-repair-shop-execution"
      k8s_service = "execution-api"
      registry    = "car-repair-shop-execution"
    }
    # The payment provider simulator the Billing Service charges through. Not
    # part of the saga, but deployed, scraped and routed like the others.
    payment = {
      namespace   = "car-repair-shop-payment"
      k8s_service = "payment-api"
      registry    = "car-repair-shop-payment"
    }
  }
}
