variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}
variable "kube_context" {
  type    = string
  default = null
}
variable "cluster_name" { type = string }
variable "region" { type = string }
variable "storage_class_name" {
  type    = string
  default = null
}
variable "service_account_annotations" {
  type    = map(string)
  default = {}
}
variable "object_storage" {
  type      = any
  sensitive = true
}
variable "postgres" {
  type      = any
  sensitive = true
}
variable "grafana_admin" {
  type      = any
  sensitive = true
}
variable "oidc" {
  type      = any
  sensitive = true
}
variable "grafana" { type = any }
variable "tempo_enabled" {
  type    = bool
  default = false
}
variable "control_plane_scraping_enabled" {
  type    = bool
  default = false
}
variable "additional_thanos_store_endpoints" {
  type    = list(string)
  default = []
}
