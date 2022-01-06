job "docker-registry" {
  datacenters = ["lab"]

  group "docker-registry" {
    network {
      mode = "bridge"
    }

    service {
      name = "docker-registry"
      port = "5000"

      connect {
        sidecar_service {}
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "registry:2.7.1"
      }
    }
  }
}
