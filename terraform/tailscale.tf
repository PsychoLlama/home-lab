data "tailscale_device" "ingress" {
  hostname = "rpi4-003"
  wait_for = "60s"
}

resource "tailscale_acl" "primary" {
  acl = jsonencode({
    tagOwners = {
      "tag:lab"             = ["autogroup:admin", "tag:lab"]
      "tag:laptop"          = ["autogroup:admin", "tag:laptop"]
      "tag:mobile"          = ["autogroup:admin", "tag:mobile"]
      "tag:nas"             = ["autogroup:admin", "tag:nas"]
      "tag:nova"            = ["autogroup:admin", "tag:nova"]
      "tag:router"          = ["autogroup:admin", "tag:router"]
      "tag:monitoring"      = ["autogroup:admin", "tag:monitoring"]
      "tag:ingress"         = ["autogroup:admin", "tag:ingress"]
      "tag:home-automation" = ["autogroup:admin", "tag:home-automation"]
    }

    grants = [
      # Laptop can reach everything
      { src = ["tag:laptop"], dst = ["*"], ip = ["*"] },

      # Phone can reach ingress.
      { src = ["tag:mobile"], dst = ["tag:ingress"], ip = ["80", "443"] },

      # Monitoring can scrape exporters on all lab nodes
      {
        src = ["tag:monitoring"]
        dst = ["tag:lab"]
        ip  = ["9090", "9100", "9153"]
      },

      # Ingress can reach Grafana on monitoring host
      {
        src = ["tag:ingress"]
        dst = ["tag:monitoring"]
        ip  = ["3000"]
      },

      # Ingress can reach Syncthing GUI and Restic on NAS
      {
        src = ["tag:ingress"]
        dst = ["tag:nas"]
        ip  = ["8000", "8384"]
      },

      # Ingress can reach Home Assistant
      {
        src = ["tag:ingress"]
        dst = ["tag:home-automation"]
        ip  = ["8123"]
      },

      # Ingress can reach UniFi controller on router
      {
        src = ["tag:ingress"]
        dst = ["tag:router"]
        ip  = ["8443"]
      }
    ]

    ssh = [
      # Laptop can SSH to all lab devices.
      {
        action = "accept"
        src    = ["tag:laptop"]
        dst    = ["tag:lab"]
        users  = ["root"]
      }
    ]
  })
}
