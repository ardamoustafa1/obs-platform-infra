variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "Stable cluster identifier attached to every metric and log."
  type        = string
  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "cluster_name cannot be empty."
  }
}

variable "region" {
  description = "Cloud or datacenter region used as a global label."
  type        = string
}

variable "namespace" {
  description = "Namespace containing the observability control plane."
  type        = string
  default     = "observability"
}

variable "storage_class_name" {
  description = "CSI StorageClass for all stateful workloads; null uses the cluster default."
  type        = string
  default     = null
}

variable "service_account_annotations" {
  description = "Cloud workload identity annotations applied to object-storage clients (IRSA, GKE Workload Identity, or Azure Workload Identity)."
  type        = map(string)
  default     = {}
}

variable "object_storage" {
  description = "S3-compatible or GCS object storage shared by Thanos, Loki, and optionally Tempo. Use workload identity by leaving credentials null when supported."
  type = object({
    type                = string
    endpoint            = optional(string)
    region              = optional(string)
    access_key          = optional(string)
    secret_key          = optional(string)
    gcs_service_account = optional(string)
    insecure            = optional(bool, false)
    s3_force_path_style = optional(bool, false)
    metrics_bucket      = string
    logs_bucket         = string
    traces_bucket       = string
  })
  sensitive = true

  validation {
    condition     = contains(["s3", "gcs"], lower(var.object_storage.type))
    error_message = "object_storage.type must be s3 or gcs."
  }

  validation {
    condition     = (var.object_storage.access_key == null) == (var.object_storage.secret_key == null)
    error_message = "S3 access_key and secret_key must either both be set or both be omitted for workload identity."
  }
}

variable "postgres" {
  description = "External PostgreSQL connection used by Grafana HA."
  type = object({
    host     = string
    port     = optional(number, 5432)
    database = optional(string, "grafana")
    username = string
    password = string
    ssl_mode = optional(string, "require")
  })
  sensitive = true
}

variable "grafana_admin" {
  description = "Break-glass Grafana administrator. Store this input in the CI secret store."
  type = object({
    username = optional(string, "platform-admin")
    password = string
  })
  sensitive = true
}

variable "oidc" {
  description = "Generic OIDC provider settings for Grafana."
  type = object({
    enabled             = optional(bool, true)
    name                = optional(string, "SSO")
    client_id           = string
    client_secret       = string
    auth_url            = string
    token_url           = string
    api_url             = string
    scopes              = optional(string, "openid profile email groups")
    allowed_domains     = optional(string, "")
    role_attribute_path = optional(string, "contains(groups[*], 'platform-admins') && 'GrafanaAdmin' || contains(groups[*], 'platform-editors') && 'Editor' || 'Viewer'")
  })
  sensitive = true
}

variable "grafana" {
  description = "Grafana public endpoint and ingress settings."
  type = object({
    host                = string
    ingress_enabled     = optional(bool, true)
    ingress_class_name  = optional(string, "nginx")
    tls_secret_name     = optional(string)
    ingress_annotations = optional(map(string), {})
  })
}

variable "tempo_enabled" {
  description = "Deploy the optional distributed tracing plane."
  type        = bool
  default     = false
}

variable "control_plane_scraping_enabled" {
  description = "Enable scheduler, controller-manager, and etcd ServiceMonitors for self-managed control planes. Managed EKS/GKE/AKS endpoints are normally unreachable."
  type        = bool
  default     = false
}

variable "additional_thanos_store_endpoints" {
  description = "Remote Thanos StoreAPI endpoints for cross-cluster/global query, for example dnssrv+_grpc._tcp.thanos.example.internal."
  type        = list(string)
  default     = []
}

variable "ingress_namespace_labels" {
  description = "Namespace labels allowed to reach Grafana, Loki gateway, and Tempo ingestion."
  type        = map(string)
  default = {
    "observability.platform/access" = "allowed"
  }
}

variable "values_files" {
  description = "Per-chart environment-specific Helm values files."
  type = object({
    kube_prometheus_stack = string
    thanos                = string
    loki                  = string
    alloy                 = string
    grafana               = string
    tempo                 = optional(string)
  })
}

variable "chart_versions" {
  description = "Pinned and tested Helm chart versions."
  type = object({
    kube_prometheus_stack = optional(string, "91.4.1")
    thanos                = optional(string, "17.3.1")
    loki                  = optional(string, "7.3.0")
    alloy                 = optional(string, "1.12.1")
    grafana               = optional(string, "10.5.15")
    tempo                 = optional(string, "1.61.3")
  })
  default = {}
}
