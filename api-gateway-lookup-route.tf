# Rota do endpoint interno de lookup de cliente.
#
# ---------------------------------------------------------------------------
# Esta rota reverte uma restricao escrita no plano do M7, e a reversao precisa
# de justificativa.
#
# A restricao era: "o endpoint interno de lookup nao e exposto no API Gateway".
# Ela foi escrita supondo que a function alcancaria a aplicacao por outro
# caminho. Nao alcanca:
#
#   - a function nao tem vpc_config, por decisao do ADR-002: ela nao toca o
#     banco, e uma ENI so acrescentaria cold start
#   - sem estar na VPC, o unico caminho ate a aplicacao e o proprio gateway
#   - o gateway nao roteava /auth/customers/lookup, entao devolvia 404
#
# O sintoma era o pior possivel: `POST /auth/cpf` com um CPF valido devolvia
# 401 "authentication failed". A function traduz 404 para "cliente nao
# encontrado", e "cliente nao encontrado" vira 401. Um erro de roteamento se
# disfarcava de credencial invalida -- plausivel o bastante para ninguem
# investigar.
#
# As duas decisoes eram individualmente corretas e incompativeis juntas. Uma
# tinha que ceder.
#
# Por que cede a restricao, e nao o ADR-002:
#
#   O ADR-002 ja aceita explicitamente este modelo de protecao, na secao de
#   riscos: "o endpoint interno e protegido pelo header x-internal-token, um
#   segredo compartilhado, e nao por mTLS. E proporcional ao escopo, mas fica
#   registrado como divida."
#
#   Ou seja: a superficie que esta rota cria ja tinha sido pesada e aceita. A
#   restricao do M7 era mais estrita que o ADR que ela deveria implementar.
#
#   A alternativa -- colocar a function na VPC para falar com o NLB interno --
#   deixaria o lookup genuinamente inalcancavel da internet, que e melhor. Mas
#   custa ENI, security group, cold start e contradiz um ADR aceito, para
#   endurecer algo que ja foi julgado proporcional. Fica registrado como o
#   caminho de endurecimento, se o escopo mudar.
# ---------------------------------------------------------------------------
#
# Camadas que protegem esta rota:
#
#   1. x-internal-token, comparado em tempo constante na aplicacao
#   2. throttling proprio, abaixo -- muito mais apertado que o padrao
#   3. rate limit na aplicacao (30/min)
#   4. ausente do Swagger publico, com teste afirmando isso
#
# Separada de var.public_routes de proposito: ela nao e publica no mesmo
# sentido das outras. Misturar as duas na mesma lista apagaria a distincao
# exatamente onde ela mais importa.
resource "aws_apigatewayv2_route" "customer_lookup" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/customers/lookup"
  target    = "integrations/${aws_apigatewayv2_integration.cluster.id}"
}
