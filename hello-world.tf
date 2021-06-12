resource "kubernetes_deployment" "hello_world" {
  metadata {
    name      = "hello-world"
    namespace = kubernetes_namespace.prod.metadata.0.name
  }

  spec {
    selector {
      match_labels = {
        app = "hello-world"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }

      spec {
        container {
          image = "crccheck/hello-world"
          name  = "hello-world"
          port {
            container_port = 8000
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "hello_world" {
  metadata {
    name      = "hello-world"
    namespace = kubernetes_namespace.prod.metadata.0.name
  }

  spec {
    selector = kubernetes_deployment.hello_world.spec.0.selector.0.match_labels

    port {
      port        = 80
      target_port = 8000
    }
  }
}
