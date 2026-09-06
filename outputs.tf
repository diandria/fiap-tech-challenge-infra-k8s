# Outputs consumed by the application and by the functions repository.

output "tempo_otlp_http_endpoint" {
  description = "Tempo OTLP HTTP receiver. Feeds the application's OTEL_EXPORTER_OTLP_ENDPOINT."
  value       = "http://tempo.${local.observability_namespace}.svc.cluster.local:4318"
}

output "loki_push_endpoint" {
  description = "Loki ingestion endpoint, for any component that pushes logs directly."
  value       = "http://loki.${local.observability_namespace}.svc.cluster.local:3100"
}

output "observability_namespace" {
  description = "Namespace where Prometheus, Grafana, Loki and Tempo live."
  value       = local.observability_namespace
}

# Re-exports what the database repository publishes, so the application reads
# everything from one state instead of knowing two backends.
output "db_endpoint" {
  description = "RDS address, read from the database repository state."
  value       = data.terraform_remote_state.db.outputs.db_endpoint
}

output "db_port" {
  description = "RDS port."
  value       = data.terraform_remote_state.db.outputs.db_port
}

output "db_name" {
  description = "Database name."
  value       = data.terraform_remote_state.db.outputs.db_name
}

output "db_password_parameter" {
  description = "Name of the SSM parameter holding the database password. Not the password."
  value       = data.terraform_remote_state.db.outputs.db_password_parameter
}

output "api_gateway_url" {
  description = "Public address of the system. The only entry path."
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_gateway_id" {
  description = "HTTP API id, referenced by the functions repository to add routes."
  value       = aws_apigatewayv2_api.main.id
}

output "vpc_link_id" {
  description = "Id of the VPC Link that reaches the internal NLB."
  value       = aws_apigatewayv2_vpc_link.main.id
}

output "ecr_repository_url" {
  description = "URL of the application ECR repository, consumed by the CD."
  value       = aws_ecr_repository.app.repository_url
}
