resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  namespace        = var.namespace
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_versions.kube_prometheus_stack
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 1200
  wait             = true
  values           = [yamlencode(local.prometheus_values), file(var.values_files.kube_prometheus_stack)]
  depends_on       = [kubernetes_secret_v1.thanos_objstore, kubernetes_network_policy_v1.same_namespace]
}

resource "helm_release" "thanos" {
  name             = "thanos"
  namespace        = var.namespace
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "thanos"
  version          = var.chart_versions.thanos
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 1200
  wait             = true
  values           = [yamlencode(local.thanos_values), file(var.values_files.thanos)]
  depends_on       = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "loki" {
  name             = "loki"
  namespace        = var.namespace
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = var.chart_versions.loki
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 1800
  wait             = true
  values           = [yamlencode(local.loki_values), file(var.values_files.loki)]
  depends_on       = [kubernetes_network_policy_v1.external_egress]
}

resource "helm_release" "alloy" {
  name             = "alloy"
  namespace        = var.namespace
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "alloy"
  version          = var.chart_versions.alloy
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 900
  wait             = true
  values           = [yamlencode(local.alloy_values), file(var.values_files.alloy)]
  depends_on       = [helm_release.loki]
}

resource "helm_release" "tempo" {
  count            = var.tempo_enabled ? 1 : 0
  name             = "tempo"
  namespace        = var.namespace
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "tempo-distributed"
  version          = var.chart_versions.tempo
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 1800
  wait             = true
  values           = [yamlencode(local.tempo_values), file(var.values_files.tempo)]
  depends_on       = [kubernetes_network_policy_v1.external_egress]
}

resource "helm_release" "grafana" {
  name             = "grafana"
  namespace        = var.namespace
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = var.chart_versions.grafana
  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 1200
  wait             = true
  values           = [yamlencode(local.grafana_values), file(var.values_files.grafana)]
  depends_on       = [helm_release.thanos, helm_release.loki, helm_release.tempo, kubernetes_secret_v1.grafana]
}

