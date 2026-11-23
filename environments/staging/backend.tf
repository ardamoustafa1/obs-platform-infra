terraform {
  backend "kubernetes" {
    secret_suffix = "obs-platform-infra-staging"
    namespace     = "kube-system"
  }
}

