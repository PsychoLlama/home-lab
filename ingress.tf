resource "kubernetes_ingress" "hello_world" {
  metadata {
    name      = "hello-world-ingress"
    namespace = kubernetes_namespace.prod.metadata.0.name
  }

  spec {
    tls {
      secret_name = kubernetes_secret.ssl_cert.metadata.0.name
      hosts       = ["selfhosted.city"]
    }

    rule {
      host = "selfhosted.city"

      http {
        path {
          path = "/"

          backend {
            service_name = kubernetes_service.hello_world.metadata.0.name
            service_port = kubernetes_service.hello_world.spec.0.port.0.port
          }
        }
      }
    }
  }
}
