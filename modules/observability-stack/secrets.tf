resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name   = var.namespace
    labels = merge(local.common_labels, { "pod-security.kubernetes.io/enforce" = "baseline", "pod-security.kubernetes.io/audit" = "restricted", "pod-security.kubernetes.io/warn" = "restricted" })
  }
}

resource "kubernetes_secret_v1" "thanos_objstore" {
  metadata {
    name      = "thanos-object-storage"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels    = local.common_labels
  }
  data = { "objstore.yml" = yamlencode(local.thanos_objstore) }
  type = "Opaque"
}

resource "kubernetes_secret_v1" "grafana" {
  metadata {
    name      = "grafana-runtime"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels    = local.common_labels
  }
  data = {
    "admin-user"                        = var.grafana_admin.username
    "admin-password"                    = var.grafana_admin.password
    GF_DATABASE_TYPE                    = "postgres"
    GF_DATABASE_HOST                    = "${var.postgres.host}:${var.postgres.port}"
    GF_DATABASE_NAME                    = var.postgres.database
    GF_DATABASE_USER                    = var.postgres.username
    GF_DATABASE_PASSWORD                = var.postgres.password
    GF_DATABASE_SSL_MODE                = var.postgres.ssl_mode
    GF_AUTH_GENERIC_OAUTH_CLIENT_ID     = var.oidc.client_id
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = var.oidc.client_secret
  }
  type = "Opaque"
}

resource "kubernetes_secret_v1" "gcs_credentials" {
  metadata {
    name      = "gcs-object-storage"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels    = local.common_labels
  }
  data = { "service-account.json" = coalesce(var.object_storage.gcs_service_account, "{}") }
  type = "Opaque"
}
