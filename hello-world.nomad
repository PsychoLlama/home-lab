job "hello-world" {
  datacenters = ["dc1"]

  group "web-server" {
    network {
      port "proxy" {
        to = 80
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:latest"

        ports = ["proxy"]
      }

      resources {
        cpu    = 500
        memory = 10
      }
    }
  }
}
