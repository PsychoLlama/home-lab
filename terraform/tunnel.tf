# Cloudflare Zero Trust Tunnel for public ingress

resource "cloudflare_zero_trust_tunnel_cloudflared" "public_ingress" {
  account_id = var.cloudflare_account_id
  name       = "home-lab-public-ingress"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "public_ingress" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.public_ingress.id

  config = {
    ingress = concat(
      [
        for name, host in local.config.ingress.public : merge(
          {
            hostname = "${name}.${local.config.lab.domain}"
            service  = host.service
          },
          host.path != null ? { path = host.path } : {},
          !host.tlsVerify ? { origin_request = { no_tls_verify = true } } : {}
        )
      ],
      [{ service = "http_status:404" }] # catch-all
    )
  }
}

# CNAME records for each public host (proxied through Cloudflare)
resource "cloudflare_dns_record" "tunnel" {
  for_each = local.config.ingress.public

  zone_id = data.cloudflare_zone.main.zone_id
  name    = each.key
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.public_ingress.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

output "tunnel_id" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.public_ingress.id
  description = "Tunnel UUID for NixOS config"
}
