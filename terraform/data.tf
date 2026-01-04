locals {
  config = jsondecode(file("${path.module}/config.json"))

  # Client device tags (not managed by NixOS, but referenced in grants)
  client_tags = ["laptop", "mobile"]

  # Collect all unique tags from VPN nodes + client tags + auto-added tags
  host_tags = distinct(flatten([
    for name, node in local.config.vpn.nodes : concat(
      node.tags,
      ["lab", local.config.lab.datacenter]
    )
  ]))

  all_tags = distinct(concat(local.client_tags, local.host_tags))
}

data "cloudflare_zone" "main" {
  filter = {
    name = local.config.lab.domain
  }
}
