locals {
  common_labels = {
    "app.kubernetes.io/part-of"    = "obs-platform"
    "app.kubernetes.io/managed-by" = "terraform"
    "platform.environment"         = var.environment
  }

  object_store_type = lower(var.object_storage.type)
  gcs_key_enabled   = local.object_store_type == "gcs" && var.object_storage.gcs_service_account != null
  gcs_env = local.gcs_key_enabled ? [{
    name  = "GOOGLE_APPLICATION_CREDENTIALS"
    value = "/var/secrets/google/service-account.json"
  }] : []
  gcs_volumes = local.gcs_key_enabled ? [{
    name   = "gcs-credentials"
    secret = { secretName = kubernetes_secret_v1.gcs_credentials.metadata[0].name }
  }] : []
  gcs_volume_mounts = local.gcs_key_enabled ? [{
    name      = "gcs-credentials"
    mountPath = "/var/secrets/google"
    readOnly  = true
  }] : []
  thanos_objstore = jsondecode(local.object_store_type == "s3" ? jsonencode({
    type = "S3"
    config = merge({
      bucket   = var.object_storage.metrics_bucket
      endpoint = coalesce(var.object_storage.endpoint, "s3.${coalesce(var.object_storage.region, var.region)}.amazonaws.com")
      region   = coalesce(var.object_storage.region, var.region)
      insecure = var.object_storage.insecure
      }, var.object_storage.access_key == null ? {} : {
      access_key = var.object_storage.access_key
      secret_key = var.object_storage.secret_key
    })
    }) : jsonencode({
    type = "GCS"
    config = {
      bucket          = var.object_storage.metrics_bucket
      service_account = var.object_storage.gcs_service_account
    }
  }))

  loki_storage = jsondecode(local.object_store_type == "s3" ? jsonencode({
    type = "s3"
    bucketNames = {
      chunks = var.object_storage.logs_bucket
      ruler  = var.object_storage.logs_bucket
      admin  = var.object_storage.logs_bucket
    }
    s3 = merge({
      region                                                   = coalesce(var.object_storage.region, var.region)
      s3ForcePathStyle                                         = var.object_storage.s3_force_path_style
      insecure                                                 = var.object_storage.insecure
      }, var.object_storage.endpoint == null ? {} : { endpoint = var.object_storage.endpoint }, var.object_storage.access_key == null ? {} : {
      accessKeyId                                              = var.object_storage.access_key
      secretAccessKey                                          = var.object_storage.secret_key
    })
    }) : jsonencode({
    type = "gcs"
    bucketNames = {
      chunks = var.object_storage.logs_bucket
      ruler  = var.object_storage.logs_bucket
      admin  = var.object_storage.logs_bucket
    }
    gcs = {}
  }))

  tempo_storage = jsondecode(local.object_store_type == "s3" ? jsonencode({
    trace = {
      backend = "s3"
      s3 = merge({
        bucket                                                   = var.object_storage.traces_bucket
        region                                                   = coalesce(var.object_storage.region, var.region)
        insecure                                                 = var.object_storage.insecure
        forcepathstyle                                           = var.object_storage.s3_force_path_style
        }, var.object_storage.endpoint == null ? {} : { endpoint = var.object_storage.endpoint }, var.object_storage.access_key == null ? {} : {
        access_key                                               = var.object_storage.access_key
        secret_key                                               = var.object_storage.secret_key
      })
    }
    }) : jsonencode({
    trace = {
      backend = "gcs"
      gcs = {
        bucket_name = var.object_storage.traces_bucket
      }
    }
  }))

  storage_class = var.storage_class_name == null ? {} : { storageClassName = var.storage_class_name }

  prometheus_values = {
    fullnameOverride      = "monitoring"
    grafana               = { enabled = false }
    kubeControllerManager = { enabled = var.control_plane_scraping_enabled }
    kubeScheduler         = { enabled = var.control_plane_scraping_enabled }
    kubeEtcd              = { enabled = var.control_plane_scraping_enabled }
    prometheus = {
      serviceAccount = { annotations = var.service_account_annotations }
      thanosService  = { enabled = true }
      prometheusSpec = {
        retention                   = "15d"
        externalLabels              = { cluster = var.cluster_name, region = var.region, environment = var.environment }
        replicaExternalLabelName    = "prometheus_replica"
        prometheusExternalLabelName = "prometheus"
        thanos = {
          objectStorageConfig = {
            existingSecret = { name = kubernetes_secret_v1.thanos_objstore.metadata[0].name, key = "objstore.yml" }
          }
        }
        storageSpec = {
          volumeClaimTemplate = {
            spec = merge(local.storage_class, {
              accessModes = ["ReadWriteOnce"]
              resources   = { requests = { storage = "100Gi" } }
            })
          }
        }
      }
    }
  }

  thanos_values = {
    global = { security = { allowInsecureImages = true } }
    image = {
      registry   = "docker.io"
      repository = "thanosio/thanos"
      tag        = "v0.39.2"
      digest     = "sha256:1d022ef4b8eff056a0e3b7822f953d931c5704d068413f2d7ce5266aa96c9e80"
    }
    existingObjstoreSecret = kubernetes_secret_v1.thanos_objstore.metadata[0].name
    query = {
      dnsDiscovery   = { enabled = true, sidecarsService = "monitoring-thanos-discovery", sidecarsNamespace = var.namespace }
      stores         = var.additional_thanos_store_endpoints
      replicaLabel   = ["prometheus_replica"]
      serviceAccount = { annotations = var.service_account_annotations }
    }
    storegateway = { enabled = true, serviceAccount = { annotations = var.service_account_annotations }, persistence = merge({ enabled = true, size = "50Gi" }, var.storage_class_name == null ? {} : { storageClass = var.storage_class_name }) }
    compactor = {
      enabled                = true
      retentionResolutionRaw = "395d"
      retentionResolution5m  = "395d"
      retentionResolution1h  = "395d"
      serviceAccount         = { annotations = var.service_account_annotations }
      persistence            = merge({ enabled = true, size = "50Gi" }, var.storage_class_name == null ? {} : { storageClass = var.storage_class_name })
    }
    bucketweb = { enabled = false }
    ruler     = { enabled = false }
    receive   = { enabled = false }
  }

  loki_values = {
    deploymentMode = "SimpleScalable"
    global = {
      extraEnv          = local.gcs_env
      extraVolumes      = local.gcs_volumes
      extraVolumeMounts = local.gcs_volume_mounts
    }
    loki = {
      auth_enabled = false
      storage      = local.loki_storage
      schemaConfig = {
        configs = [{ from = "2024-04-01", store = "tsdb", object_store = local.object_store_type, schema = "v13", index = { prefix = "loki_index_", period = "24h" } }]
      }
      limits_config = { retention_period = "8760h", ingestion_rate_mb = 20, ingestion_burst_size_mb = 40, max_query_parallelism = 32 }
      compactor     = { retention_enabled = true, delete_request_store = local.object_store_type }
    }
    serviceAccount = {
      annotations = var.service_account_annotations
    }
  }

  alloy_config = <<-RIVER
    logging { level = "info" format = "logfmt" }

    discovery.kubernetes "pods" {
      role = "pod"
      selectors { role = "pod" field = "spec.nodeName=" + sys.env("HOSTNAME") }
    }

    discovery.relabel "pod_logs" {
      targets = discovery.kubernetes.pods.targets
      rule { source_labels = ["__meta_kubernetes_namespace"] target_label = "namespace" }
      rule { source_labels = ["__meta_kubernetes_pod_name"] target_label = "pod" }
      rule { source_labels = ["__meta_kubernetes_pod_container_name"] target_label = "container" }
      rule { source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"] target_label = "app" }
      rule { source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"] separator = "/" target_label = "__path__" replacement = "/var/log/pods/*$1/*.log" }
      rule { target_label = "cluster" replacement = "${var.cluster_name}" }
      rule { target_label = "region" replacement = "${var.region}" }
      rule { target_label = "environment" replacement = "${var.environment}" }
    }

    local.file_match "pod_logs" { path_targets = discovery.relabel.pod_logs.output sync_period = "10s" }
    loki.source.file "pod_logs" {
      targets       = local.file_match.pod_logs.targets
      forward_to    = [loki.process.pod_logs.receiver]
      tail_from_end = true
    }
    loki.process "pod_logs" {
      stage.cri {}
      stage.static_labels { values = { platform = "kubernetes" } }
      forward_to = [loki.write.default.receiver]
    }
    loki.write "default" {
      endpoint { url = "http://loki-gateway.${var.namespace}.svc.cluster.local/loki/api/v1/push" }
      external_labels = { cluster = "${var.cluster_name}" }
    }
  RIVER

  alloy_values = {
    controller = { type = "daemonset" }
    alloy = {
      configMap = { create = true, content = local.alloy_config }
      mounts    = { varlog = true }
    }
  }

  grafana_values = {
    replicas            = 2
    admin               = { existingSecret = kubernetes_secret_v1.grafana.metadata[0].name, userKey = "admin-user", passwordKey = "admin-password" }
    envFromSecrets      = [{ name = kubernetes_secret_v1.grafana.metadata[0].name }]
    persistence         = { enabled = false }
    podDisruptionBudget = { minAvailable = 1 }
    ingress = {
      enabled          = var.grafana.ingress_enabled
      ingressClassName = var.grafana.ingress_class_name
      annotations      = var.grafana.ingress_annotations
      hosts            = [var.grafana.host]
      path             = "/"
      tls              = var.grafana.tls_secret_name == null ? [] : [{ secretName = var.grafana.tls_secret_name, hosts = [var.grafana.host] }]
    }
    "grafana.ini" = {
      server = { root_url = "https://${var.grafana.host}" }
      users  = { allow_sign_up = false }
      auth   = { disable_login_form = var.oidc.enabled, oauth_auto_login = var.oidc.enabled }
      "auth.generic_oauth" = {
        enabled             = var.oidc.enabled
        name                = var.oidc.name
        client_id           = "$__env{GF_AUTH_GENERIC_OAUTH_CLIENT_ID}"
        client_secret       = "$__env{GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET}"
        scopes              = var.oidc.scopes
        auth_url            = var.oidc.auth_url
        token_url           = var.oidc.token_url
        api_url             = var.oidc.api_url
        allowed_domains     = var.oidc.allowed_domains
        role_attribute_path = var.oidc.role_attribute_path
        allow_sign_up       = true
      }
    }
    datasources = {
      "datasources.yaml" = {
        apiVersion = 1
        datasources = concat([
          { name = "Thanos", uid = "thanos", type = "prometheus", access = "proxy", url = "http://thanos-query.${var.namespace}.svc.cluster.local:9090", isDefault = true, editable = false, jsonData = { prometheusType = "Thanos", timeInterval = "30s" } },
          { name = "Loki", uid = "loki", type = "loki", access = "proxy", url = "http://loki-gateway.${var.namespace}.svc.cluster.local", editable = false }
        ], var.tempo_enabled ? [{ name = "Tempo", uid = "tempo", type = "tempo", access = "proxy", url = "http://tempo-query-frontend.${var.namespace}.svc.cluster.local:3200", editable = false, jsonData = { tracesToLogsV2 = { datasourceUid = "loki" }, serviceMap = { datasourceUid = "thanos" }, nodeGraph = { enabled = true } } }] : [])
      }
    }
  }

  tempo_values = {
    multitenancyEnabled = false
    serviceAccount      = { annotations = var.service_account_annotations }
    ingester            = { extraEnv = local.gcs_env, extraVolumes = local.gcs_volumes, extraVolumeMounts = local.gcs_volume_mounts }
    distributor         = { extraEnv = local.gcs_env, extraVolumes = local.gcs_volumes, extraVolumeMounts = local.gcs_volume_mounts }
    querier             = { extraEnv = local.gcs_env, extraVolumes = local.gcs_volumes, extraVolumeMounts = local.gcs_volume_mounts }
    queryFrontend       = { extraEnv = local.gcs_env, extraVolumes = local.gcs_volumes, extraVolumeMounts = local.gcs_volume_mounts }
    compactor           = { extraEnv = local.gcs_env, extraVolumes = local.gcs_volumes, extraVolumeMounts = local.gcs_volume_mounts, config = { compaction = { block_retention = "8760h" } } }
    traces              = { otlp = { grpc = { enabled = true }, http = { enabled = true } } }
    storage             = local.tempo_storage
  }
}
