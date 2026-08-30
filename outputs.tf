# Outputs consumidos pela aplicacao (M8) e pelo repositorio das functions (M6).

output "tempo_otlp_http_endpoint" {
  description = "Receptor OTLP HTTP do Tempo. Alimenta OTEL_EXPORTER_OTLP_ENDPOINT da aplicacao (M8.T3)."
  value       = "http://tempo.${local.observability_namespace}.svc.cluster.local:4318"
}

output "loki_push_endpoint" {
  description = "Endpoint de ingestao do Loki, caso algum componente precise empurrar log direto."
  value       = "http://loki.${local.observability_namespace}.svc.cluster.local:3100"
}

output "observability_namespace" {
  description = "Namespace onde vivem Prometheus, Grafana, Loki e Tempo."
  value       = local.observability_namespace
}

# Repassa o que o repositorio do banco publica. Assim a aplicacao (M8) le tudo
# de um unico estado, em vez de precisar conhecer dois backends.
output "db_endpoint" {
  description = "Endereco do RDS, lido do estado do repositorio do banco."
  value       = data.terraform_remote_state.db.outputs.db_endpoint
}

output "db_port" {
  description = "Porta do RDS."
  value       = data.terraform_remote_state.db.outputs.db_port
}

output "db_name" {
  description = "Nome do banco."
  value       = data.terraform_remote_state.db.outputs.db_name
}

output "db_password_parameter" {
  description = "Nome do parametro SSM com a senha do banco. Nao e a senha."
  value       = data.terraform_remote_state.db.outputs.db_password_parameter
}

output "api_gateway_url" {
  description = "Endereco publico do sistema. Unico caminho de entrada."
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_gateway_id" {
  description = "Id do HTTP API. O repositorio das functions referencia para adicionar rotas."
  value       = aws_apigatewayv2_api.main.id
}

output "vpc_link_id" {
  description = "Id do VPC Link que alcanca o NLB interno."
  value       = aws_apigatewayv2_vpc_link.main.id
}
