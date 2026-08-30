resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = local.observability_namespace
  }
}

# Senha gerada aqui e guardada em Secret. Nunca no values do chart: este
# repositorio e publico, e values de Helm entram no commit.
resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
  }

  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_admin.result
  }

  type = "Opaque"
}
