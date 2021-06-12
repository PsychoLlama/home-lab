resource "kubernetes_secret" "ssl_cert" {
  metadata {
    name      = "selfhosted-city-cert"
    namespace = kubernetes_namespace.prod.metadata.0.name
  }

  data = {
    "tls.crt" = filebase64("./config/selfhosted.city.crt")
    "tls.key" = filebase64("./config/selfhosted.city.key")
  }

  type = "kubernetes.io/tls"
}
