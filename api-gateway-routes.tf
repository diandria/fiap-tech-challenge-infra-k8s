# Gateway resources that depend on the application NLB.
#
# The NLB is born from the Service in k8s/02-service/ of the application
# repository. Nothing here can be planned before that Service exists:
# `data.aws_lb` fails the plan, not just the apply.
#
# So everything depending on the NLB or the function sits behind
# var.enable_gateway_routes. During the first phase of a from-scratch provision
# the variable is `false` and none of these resources enter the plan; the second
# apply, with the default `true`, creates integration, routes and permission.

# The NLB is born from the Kubernetes Service, not from a Terraform resource, so
# it is discovered through the tags the AWS Load Balancer Controller applies.
data "aws_lb" "api" {
  count = var.enable_gateway_routes ? 1 : 0

  tags = {
    "service.k8s.aws/stack" = "${local.app_namespace}/${local.app_service_name}"
  }
}

data "aws_lb_listener" "api" {
  count = var.enable_gateway_routes ? 1 : 0

  load_balancer_arn = data.aws_lb.api[0].arn
  port              = 80
}

resource "aws_apigatewayv2_integration" "cluster" {
  count = var.enable_gateway_routes ? 1 : 0

  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = data.aws_lb_listener.api[0].arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  payload_format_version = "1.0"
  timeout_milliseconds   = 29000
}

# Routes are enumerated rather than a wildcard ANY /{proxy+}.
#
# With a wildcard every future endpoint would be reachable by default, with
# nobody deciding. Enumerating forces one written decision per route.
#
# The internal lookup has its own route in api-gateway-lookup-route.tf, outside
# this list on purpose.
#
# The cost: a new prefix in the application needs a new route here, and
# forgetting produces a 404 on an endpoint that exists. That is why the list is
# a visible variable rather than buried in the resource.
resource "aws_apigatewayv2_route" "public" {
  for_each = var.enable_gateway_routes ? toset(var.public_routes) : toset([])

  api_id    = aws_apigatewayv2_api.main.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.cluster[0].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  # Throttling is what makes this control and routing rather than a plain proxy.
  default_route_settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }

  # The internal lookup has its own ceiling, far below the default. Its only
  # legitimate caller is the function, which makes one query per authentication.
  # If the shared secret leaked, this ceiling is what separates a single lookup
  # from a sweep of CPFs.
  #
  # Dynamic because the route only exists with var.enable_gateway_routes: a
  # route_settings pointing at a missing route fails the stage apply.
  dynamic "route_settings" {
    for_each = var.enable_gateway_routes ? [1] : []

    content {
      route_key              = aws_apigatewayv2_route.customer_lookup[0].route_key
      throttling_rate_limit  = var.lookup_throttling_rate_limit
      throttling_burst_limit = var.lookup_throttling_burst_limit
    }
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn

    # JSON, not text: the logs across the system are structured, and plain text
    # here would break querying.
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
