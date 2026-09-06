# Integration with the function that issues the customer JWT.
#
# AWS_PROXY, not HTTP_PROXY: the gateway hands the whole event to Lambda and
# returns whatever it answers, without a VPC Link, because the function is not
# in the VPC (ADR-002).
resource "aws_apigatewayv2_integration" "auth_lambda" {
  # The function ARN comes from the functions repository's remote state, which
  # does not exist yet during the first phase of a from-scratch provision. See
  # api-gateway-routes.tf about var.enable_gateway_routes.
  count = var.enable_gateway_routes ? 1 : 0

  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = data.terraform_remote_state.lambda.outputs.auth_lambda_invoke_arn

  # 2.0 is the format the function expects: the handler reads event.body and
  # returns { statusCode, headers, body }.
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

# A specific route. The public routes on this gateway are enumerated, so it
# competes with no wildcard, and the HTTP API would prioritise the specific one
# regardless.
resource "aws_apigatewayv2_route" "auth_cpf" {
  count = var.enable_gateway_routes ? 1 : 0

  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/cpf"
  target    = "integrations/${aws_apigatewayv2_integration.auth_lambda[0].id}"
}

# Without this permission the route exists, looks correct in the console, and
# every call returns 500: the gateway cannot invoke and nothing says why.
resource "aws_lambda_permission" "api_gateway_invoke_auth" {
  count = var.enable_gateway_routes ? 1 : 0

  statement_id  = "AllowInvokeFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.auth_lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # Restricted to this gateway and route: without source_arn, any API Gateway in
  # the account could invoke the function.
  source_arn = "${aws_apigatewayv2_api.main.execution_arn}/*/POST/auth/cpf"
}
