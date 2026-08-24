{ config, lib, ... }:

let
  cfg = config.lab.stacks.ingress.public;
in

{
  options.lab.stacks.ingress.public = {
    enable = lib.mkEnableOption "public ingress stack (Cloudflare Tunnel + VPN)";

    acl.tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "public-gateway";
      description = "Tailscale ACL tag for this stack";
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ cfg.acl.tag ];

    lab.services.tunnel = {
      enable = true;

      # Webhook IDs are the secret, not the endpoint. IDs are random UUIDs
      # stored in Home Assistant, not this repo.
      #
      # Routes through Caddy (home.selfhosted.city) for access logging and
      # consistent TLS termination. Resolves via Tailscale split-horizon DNS.
      hosts.home = {
        service = "https://home.selfhosted.city";
        path = "/api/webhook/.*";
        acl.tag = config.lab.stacks.ingress.private.acl.tag;
      };
    };
  };
}
