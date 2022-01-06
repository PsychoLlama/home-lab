job "private-ingress" {
  datacenters = ["lab"]
  type        = "system"

  group "ingress" {
    network {
      mode = "bridge"
    }

    service {
      name = "private-ingress"
      port = "8080"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "docker-registry"
              local_bind_port  = 3000
            }
          }
        }
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:v2.5.5"
        args  = ["--configFile=/local/traefik.yml"]
      }

      template {
        destination = "local/traefik.yml"
        data        = <<EOF
          entryPoints:
            web:
              address: ':8080'

          providers:
            file:
              directory: /local/traefik-routes.yml
        EOF
      }

      template {
        destination = "local/traefik-routes.yml"
        data        = <<EOF
          http:
            routers:
              docker:
                rule: "Host(`docker.selfhosted.city`)"
                service: docker-registry

            services:
              docker-registry:
                loadBalancer:
                  servers:
                    - url: http://localhost:3000
        EOF
      }
    }
  }
}
