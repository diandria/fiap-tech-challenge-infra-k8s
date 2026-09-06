# Route for the internal customer lookup endpoint.
#
# The function reaches the application only through this gateway: it has no
# vpc_config (ADR-002), so without this route /auth/customers/lookup answered
# 404, the function translated that to "customer not found", and POST /auth/cpf
# failed with 401 for a valid CPF. A routing error disguised as a bad
# credential.
#
# ADR-002 already accepts this protection model in its risk section: the
# endpoint is guarded by the x-internal-token shared secret rather than mTLS,
# proportional to the scope and recorded as debt. Putting the function inside
# the VPC would make the lookup genuinely unreachable from the internet, and
# stays the hardening path if the scope changes.
#
# Layers protecting this route:
#
#   1. x-internal-token, compared in constant time by the application
#   2. its own throttling below, much tighter than the default
#   3. rate limit in the application (30/min)
#   4. absent from the public Swagger, with a test asserting it
#
# Kept out of var.public_routes on purpose: it is not public in the same sense
# as the others, and mixing them would erase the distinction.
resource "aws_apigatewayv2_route" "customer_lookup" {
  count = var.enable_gateway_routes ? 1 : 0

  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/customers/lookup"
  target    = "integrations/${aws_apigatewayv2_integration.cluster[0].id}"
}
