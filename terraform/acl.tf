resource "tailscale_acl" "primary" {
  acl = jsonencode({
    tagOwners = {
      "tag:lab"        = ["autogroup:admin", "tag:lab"]
      "tag:laptop"     = ["autogroup:admin", "tag:laptop"]
      "tag:mobile"     = ["autogroup:admin", "tag:mobile"]
      "tag:nas"        = ["autogroup:admin", "tag:nas"]
      "tag:nova"       = ["autogroup:admin", "tag:nova"]
      "tag:router"     = ["autogroup:admin", "tag:router"]
      "tag:monitoring" = ["autogroup:admin", "tag:monitoring"]
      "tag:ingress"    = ["autogroup:admin", "tag:ingress"]
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
