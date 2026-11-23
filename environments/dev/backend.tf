terraform {
  backend "kubernetes" {
    secret_suffix = "obs-platform-infra-dev"
    namespace     = "kube-system"
  }
}

