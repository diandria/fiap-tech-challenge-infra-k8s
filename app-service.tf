# O Service da aplicacao mora aqui, e nao no repositorio da aplicacao, por uma
# razao concreta: e ele que faz nascer o NLB, e o API Gateway precisa do ARN do
# listener desse NLB. Se o Service viesse junto do deploy da aplicacao, o
# gateway so poderia ser criado depois -- e o endereco publico do sistema
# mudaria a cada redeploy.
#
# Assim o NLB e o endereco do gateway sao infraestrutura estavel. O M8 apenas
# cria os pods que este Service passa a selecionar.
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = local.app_namespace
  }
}

resource "kubernetes_service_v1" "api" {
  metadata {
    name      = local.app_service_name
    namespace = kubernetes_namespace_v1.app.metadata[0].name

    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"

      # Interno, nunca publico: o ADR-001 estabelece o API Gateway como ponto
      # unico de entrada. Um NLB publico criaria um caminho paralelo que ignora
      # throttling, CORS e autenticacao do gateway.
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal"

      # Health check no endpoint de liveness da aplicacao (M3.T7).
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol" = "HTTP"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path"     = "/health"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"     = "3000"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = local.app_service_name
    }

    port {
      port        = 80
      target_port = 3000
      protocol    = "TCP"
    }
  }

  # Espera o NLB ser provisionado antes de seguir: o gateway depende do ARN do
  # listener, que so existe depois disso.
  wait_for_load_balancer = true

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_ec2_tag.subnet_internal_elb,
  ]
}
