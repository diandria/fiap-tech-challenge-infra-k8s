# Recursos do gateway que dependem do NLB da aplicacao.
#
# O NLB nasce do Service em k8s/02-service/ do repositorio da aplicacao. Nada
# aqui pode ser planejado antes que aquele Service exista: `data.aws_lb` falha
# o plano, e nao apenas o apply.
#
# Por isso este arquivo sai do lugar durante a primeira fase do provisionamento
# e volta na segunda, depois do deploy da aplicacao. O mesmo tratamento que
# api-gateway-auth-route.tf recebe pela dependencia com a function.

# O NLB nasce do Service do Kubernetes, nao de um recurso do Terraform. Para
# ligar o gateway nele e preciso descobri-lo pelas tags que o AWS Load Balancer
# Controller aplica.
data "aws_lb" "api" {
  tags = {
    "service.k8s.aws/stack" = "${local.app_namespace}/${local.app_service_name}"
  }
}

data "aws_lb_listener" "api" {
  load_balancer_arn = data.aws_lb.api.arn
  port              = 80
}

resource "aws_apigatewayv2_integration" "cluster" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = data.aws_lb_listener.api.arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  payload_format_version = "1.0"
  timeout_milliseconds   = 29000
}

# Rotas enumeradas, e nao um curinga ANY /{proxy+}.
#
# Com curinga, todo endpoint futuro nasceria alcancavel por padrao, sem ninguem
# decidir. Enumerar obriga a decisao a ser tomada uma vez por rota, por escrito.
#
# O lookup interno tem rota propria em api-gateway-lookup-route.tf, fora desta
# lista de proposito: ele nao e publico no mesmo sentido das outras, e misturar
# os dois casos aqui apagaria a distincao.
#
# O custo desta escolha: prefixo novo na aplicacao exige rota nova aqui.
# Esquecer produz 404 em endpoint que existe -- por isso a lista fica visivel
# numa variavel, e nao escondida no meio do recurso.
resource "aws_apigatewayv2_route" "public" {
  for_each = toset(var.public_routes)

  api_id    = aws_apigatewayv2_api.main.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.cluster.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  # O throttling e o que atende "API Gateway para controle e roteamento".
  # Sem ele, o gateway e so um proxy: nao controla nada.
  default_route_settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }

  # O lookup interno tem teto proprio, muito abaixo do padrao. O unico chamador
  # legitimo e a function, e ela faz uma consulta por autenticacao: nenhum uso
  # honesto chega perto disto. Com o segredo comprometido, este teto e o que
  # separa uma consulta pontual de uma varredura de CPFs.
  route_settings {
    route_key              = aws_apigatewayv2_route.customer_lookup.route_key
    throttling_rate_limit  = var.lookup_throttling_rate_limit
    throttling_burst_limit = var.lookup_throttling_burst_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn

    # JSON, e nao texto: o log da fase inteira e estruturado desde o M2, e
    # texto aqui quebraria a consulta.
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      latency          = "$context.responseLatency"
    })
  }
}
