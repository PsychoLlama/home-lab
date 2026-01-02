{ lib, nodes, ... }:

let
  # Read lab config from any node (shared via defaults)
  labConfig = (lib.head (lib.attrValues nodes)).config.lab;
  domain = labConfig.domain;

  # Find nodes with tunnel service enabled
  tunnelHosts = lib.filterAttrs (_: node: node.config.lab.services.tunnel.enable) nodes;
in

# Only generate resources if tunnel is enabled somewhere
lib.mkIf (tunnelHosts != { }) (
  let
    tunnelHostName = lib.head (lib.attrNames tunnelHosts);
    hosts = tunnelHosts.${tunnelHostName}.config.lab.services.tunnel.hosts;

    # Generate ingress rules for Terraform
    ingressRules =
      lib.mapAttrsToList (
        name: host:
        {
          hostname = "${name}.${domain}";
          service = host.service;
        }
        // lib.optionalAttrs (host.path != null) {
          path = host.path;
        }
        // lib.optionalAttrs (!host.tls.verify) {
          origin_request.no_tls_verify = true;
        }
      ) hosts
      ++ [
        { service = "http_status:404"; } # catch-all
      ];
  in

  assert lib.assertMsg (
    lib.length (lib.attrNames tunnelHosts) <= 1
  ) "Multiple hosts have tunnel enabled: ${toString (lib.attrNames tunnelHosts)}";

  {
    # Create the Cloudflare Tunnel
    resource.cloudflare_zero_trust_tunnel_cloudflared.public_ingress = {
      account_id = "\${var.cloudflare_account_id}";
      name = "home-lab-public-ingress";
    };

    # Configure ingress rules (remotely-managed)
    resource.cloudflare_zero_trust_tunnel_cloudflared_config.public_ingress = {
      account_id = "\${var.cloudflare_account_id}";
      tunnel_id = "\${cloudflare_zero_trust_tunnel_cloudflared.public_ingress.id}";

      config.ingress = ingressRules;
    };

    # CNAME records for each public host (proxied through Cloudflare)
    resource.cloudflare_dns_record = lib.mapAttrs' (name: _: {
      name = "tunnel-${name}";
      value = {
        zone_id = "\${data.cloudflare_zone.main.zone_id}";
        name = name;
        type = "CNAME";
        content = "\${cloudflare_zero_trust_tunnel_cloudflared.public_ingress.id}.cfargotunnel.com";
        ttl = 1;
        proxied = true;
      };
    }) hosts;

    # Outputs for manual steps
    output.tunnel_id = {
      value = "\${cloudflare_zero_trust_tunnel_cloudflared.public_ingress.id}";
      description = "Tunnel UUID for NixOS config";
    };
  }
)
