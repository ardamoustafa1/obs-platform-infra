output "namespace" { value = var.namespace }
output "grafana_url" { value = "https://${var.grafana.host}" }
output "thanos_query_url" { value = "http://thanos-query.${var.namespace}.svc.cluster.local:9090" }
output "loki_push_url" { value = "http://loki-gateway.${var.namespace}.svc.cluster.local/loki/api/v1/push" }
output "tempo_otlp_grpc_endpoint" { value = var.tempo_enabled ? "tempo-distributor.${var.namespace}.svc.cluster.local:4317" : null }

