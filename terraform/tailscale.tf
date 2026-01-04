locals {
  # Parse "host:port" or "https://host:port" -> port
  ingress_grants = [
    for name, vhost in local.config.ingress.private : {
      src = ["tag:ingress"]
      dst = ["tag:${vhost.targetTag}"]
      ip  = [split(":", replace(replace(vhost.backend, "https://", ""), "http://", ""))[1]]
    }
  ]

  static_grants = [
    # Cloudflare Tunnel -> Caddy (both on ingress host)
    {
      src = ["tag:public-gateway"]
      dst = ["tag:ingress"]
      ip  = ["443"]
    },

    # Home Assistant -> ingress for ntfy-sh alerts
    {
      src = ["tag:home-automation"]
      dst = ["tag:ingress"]
      ip  = ["443"]
    },

    # Monitoring access (scrape all lab nodes on exporter ports)
    {
      src = ["tag:monitoring"]
      dst = ["tag:lab"]
      ip  = ["9090", "9100", "9153"]
    },

    # Devices managed outside the home lab.
    {
      src = ["tag:laptop"]
      dst = ["*"]
      ip  = ["*"]
    },

    {
      src = ["tag:mobile"]
      dst = ["tag:ingress"]
      ip  = ["80", "443"]
    },

    # All devices can use the router's DNS server for split horizon DNS
    {
      src = ["*"]
      dst = ["tag:router"]
      ip  = ["53"]
    },
  ]

  acl = {
    tagOwners = { for tag in local.all_tags : "tag:${tag}" => ["autogroup:admin", "tag:${tag}"] }

    grants = concat(local.ingress_grants, local.static_grants)

    ssh = [
      {
        action = "accept"
        src    = ["tag:laptop"]
        dst    = ["tag:lab"]
        users  = ["root"]
      },
    ]
  }
}

resource "tailscale_acl" "primary" {
  acl = jsonencode(local.acl)
}

# Look up each VPN-enabled device by hostname
data "tailscale_device" "nodes" {
  for_each = local.config.vpn.nodes
  hostname = each.key
}

# Apply tags to each device via Terraform (instead of --advertise-tags)
# depends_on ACL because tags must exist in tagOwners before assignment.
resource "tailscale_device_tags" "nodes" {
  for_each   = local.config.vpn.nodes
  device_id  = data.tailscale_device.nodes[each.key].id
  tags       = [for t in concat(each.value.tags, ["lab", local.config.lab.datacenter]) : "tag:${t}"]
  depends_on = [tailscale_acl.primary]
}

# Split horizon DNS: forward domain queries to the router's CoreDNS
resource "tailscale_dns_split_nameservers" "private_services" {
  domain      = local.config.lab.domain
  nameservers = [data.tailscale_device.nodes[local.config.router.hostName].addresses[0]]
}
