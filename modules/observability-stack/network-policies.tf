resource "kubernetes_network_policy_v1" "default_deny" {
  metadata {
    name      = "default-deny"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels    = local.common_labels
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "same_namespace" {
  metadata {
    name      = "allow-same-namespace"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels    = local.common_labels
  }
  spec {
    pod_selector {}
    ingress {
      from {
        pod_selector {}
      }
    }
    egress {
      to {
        pod_selector {}
      }
    }
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "dns_egress" {
  metadata {
    name      = "allow-dns"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels    = local.common_labels
  }
  spec {
    pod_selector {}
    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
      ports {
        protocol = "TCP"
        port     = "53"
      }
    }
    policy_types = ["Egress"]
  }
}

resource "kubernetes_network_policy_v1" "external_egress" {
  metadata {
    name      = "allow-required-external-egress"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels    = local.common_labels
  }
  spec {
    pod_selector {}
    egress {
      to {
        ip_block { cidr = "0.0.0.0/0" }
      }
      ports {
        protocol = "TCP"
        port     = "443"
      }
      ports {
        protocol = "TCP"
        port     = "80"
      }
      ports {
        protocol = "TCP"
        port     = "6443"
      }
      ports {
        protocol = "TCP"
        port     = "10249"
      }
      ports {
        protocol = "TCP"
        port     = "10250"
      }
      ports {
        protocol = "TCP"
        port     = "10257"
      }
      ports {
        protocol = "TCP"
        port     = "10259"
      }
      ports {
        protocol = "TCP"
        port     = "2381"
      }
      ports {
        protocol = "TCP"
        port     = tostring(var.postgres.port)
      }
    }
    policy_types = ["Egress"]
  }
}

resource "kubernetes_network_policy_v1" "approved_ingress" {
  metadata {
    name      = "allow-observability-clients"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels    = local.common_labels
  }
  spec {
    pod_selector {}
    ingress {
      from {
        namespace_selector {
          match_labels = var.ingress_namespace_labels
        }
      }
      ports {
        protocol = "TCP"
        port     = "3000"
      }
      ports {
        protocol = "TCP"
        port     = "8080"
      }
      ports {
        protocol = "TCP"
        port     = "4317"
      }
      ports {
        protocol = "TCP"
        port     = "4318"
      }
    }
    policy_types = ["Ingress"]
  }
}
