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
