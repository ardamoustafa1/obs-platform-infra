terraform {
  backend "kubernetes" {
    secret_suffix = "obs-platform-infra-prod"
    namespace     = "kube-system"
  }
}

