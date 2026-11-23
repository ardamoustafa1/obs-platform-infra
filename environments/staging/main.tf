provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kube_context
}
provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kube_context
  }
}

module "observability" {
  source                            = "../../modules/observability-stack"
  environment                       = "staging"
  cluster_name                      = var.cluster_name
  region                            = var.region
  storage_class_name                = var.storage_class_name
  service_account_annotations       = var.service_account_annotations
  object_storage                    = var.object_storage
  postgres                          = var.postgres
  grafana_admin                     = var.grafana_admin
  oidc                              = var.oidc
  grafana                           = var.grafana
  tempo_enabled                     = var.tempo_enabled
  control_plane_scraping_enabled    = var.control_plane_scraping_enabled
  additional_thanos_store_endpoints = var.additional_thanos_store_endpoints
  values_files = {
    kube_prometheus_stack = "${path.module}/values/kube-prometheus-stack.yaml"
    thanos                = "${path.module}/values/thanos.yaml"
    loki                  = "${path.module}/values/loki.yaml"
    alloy                 = "${path.module}/values/alloy.yaml"
    grafana               = "${path.module}/values/grafana.yaml"
    tempo                 = "${path.module}/values/tempo.yaml"
  }
}

output "endpoints" { value = { grafana = module.observability.grafana_url, thanos = module.observability.thanos_query_url, loki = module.observability.loki_push_url, tempo = module.observability.tempo_otlp_grpc_endpoint } }
