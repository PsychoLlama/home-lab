terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.18"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

variable "cloudflare_api_key" {
  type      = string
  sensitive = true
}

provider "tailscale" {}

provider "cloudflare" {
  api_token = var.cloudflare_api_key
}

# Look up the zone for selfhosted.city
data "cloudflare_zone" "main" {
  filter = {
    name = "selfhosted.city"
  }
}

# Get the Tailscale device for the ingress host
data "tailscale_device" "ingress" {
  hostname = "rpi4-003"
  wait_for = "60s"
}

# DNS record pointing to the ingress host's Tailscale IP
resource "cloudflare_dns_record" "grafana" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = "grafana"
  type    = "A"
  content = data.tailscale_device.ingress.addresses[0]
  ttl     = 300
  proxied = false
}
