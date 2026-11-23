resource "kubernetes_pod_disruption_budget_v1" "loki" {
  for_each = toset(["read", "write", "backend"])
  metadata {
    name      = "loki-${each.key}"
    namespace = var.namespace
    labels    = local.common_labels
  }
  spec {
    min_available = var.environment == "dev" ? "0" : (var.environment == "prod" ? "2" : "1")
    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "loki"
        "app.kubernetes.io/component" = each.key
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.observability]
}

