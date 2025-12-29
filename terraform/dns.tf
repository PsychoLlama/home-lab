data "cloudflare_zone" "main" {
  filter = {
    name = "selfhosted.city"
  }
}

# DNS records pointing to the ingress host's Tailscale IP
resource "cloudflare_dns_record" "grafana" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = "grafana"
  type    = "A"
  content = data.tailscale_device.ingress.addresses[0]
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "syncthing" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = "syncthing"
  type    = "A"
  content = data.tailscale_device.ingress.addresses[0]
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "restic" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = "restic"
  type    = "A"
  content = data.tailscale_device.ingress.addresses[0]
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "home" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = "home"
  type    = "A"
  content = data.tailscale_device.ingress.addresses[0]
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "unifi" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = "unifi"
  type    = "A"
  content = data.tailscale_device.ingress.addresses[0]
  ttl     = 300
  proxied = false
}
