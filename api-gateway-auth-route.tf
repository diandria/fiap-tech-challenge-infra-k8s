# Integracao com a function que emite o JWT de cliente.
#
# AWS_PROXY, e nao HTTP_PROXY: o gateway entrega o evento inteiro a Lambda e
# devolve o que ela responder, sem passar por VPC Link -- a function nao esta
# na VPC, por decisao do ADR-002.
resource "aws_apigatewayv2_integration" "auth_lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = data.terraform_remote_state.lambda.outputs.auth_lambda_invoke_arn

  # 2.0 e o formato que a function espera: o handler le event.body e devolve
  # { statusCode, headers, body }.
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

# Rota especifica. As rotas publicas deste gateway sao enumeradas, entao esta
# nao disputa com curinga nenhum -- mas o HTTP API priorizaria a especifica de
# qualquer forma.
resource "aws_apigatewayv2_route" "auth_cpf" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/cpf"
  target    = "integrations/${aws_apigatewayv2_integration.auth_lambda.id}"
}

# Sem esta permissao a rota existe, aparece correta no console, e toda chamada
# devolve 500 -- o gateway nao consegue invocar e nada indica o motivo.
resource "aws_lambda_permission" "api_gateway_invoke_auth" {
  statement_id  = "AllowInvokeFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.auth_lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # Restringe a este gateway e a esta rota: sem o source_arn, qualquer API
  # Gateway da conta poderia invocar a function.
  source_arn = "${aws_apigatewayv2_api.main.execution_arn}/*/POST/auth/cpf"
}
