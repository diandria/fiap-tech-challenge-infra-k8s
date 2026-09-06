# Node security group, created by EKS. The VPC Link needs it to reach the NLB
# targets.
data "aws_eks_cluster" "main" {
  name       = aws_eks_cluster.main.name
  depends_on = [aws_eks_cluster.main]
}

# The slowest resource to create and destroy in this repository, which is why
# the runbook budgets time for it.
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = local.cluster_name
  subnet_ids         = data.aws_subnets.cluster.ids
  security_group_ids = [data.aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
}

resource "aws_apigatewayv2_api" "main" {
  name          = local.cluster_name
  protocol_type = "HTTP"
  description   = "Single entry point for the workshop system"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["content-type", "authorization", "x-internal-token"]
    max_age       = 300
  }
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.cluster_name}"
  retention_in_days = 7
}
