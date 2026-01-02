{ config, lib, ... }:

let
  cfg = config.lab.stacks.ingress.public;
in

{
  options.lab.stacks.ingress.public = {
    enable = lib.mkEnableOption "public ingress stack (Cloudflare Tunnel + VPN)";
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client = {
      enable = true;
      tags = [ "ingress" ];
    };

    lab.services.tunnel = {
      enable = true;

      # Webhook IDs are the secret, not the endpoint. IDs are random UUIDs
      # stored in Home Assistant, not this repo.
      hosts.webhooks = {
        service = "http://rpi4-002:8123";
        path = "/api/webhook/.*";
        acl.tag = "home-automation";
      };
    };
  };
}
