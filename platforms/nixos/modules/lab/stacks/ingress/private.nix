{ config, lib, ... }:

let
  cfg = config.lab.stacks.ingress.private;
in

{
  options.lab.stacks.ingress.private = {
    enable = lib.mkEnableOption "private ingress stack (Caddy + VPN)";

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            serverName = lib.mkOption {
              type = lib.types.str;
              description = "FQDN for this virtual host";
            };
            backend = lib.mkOption {
              type = lib.types.str;
              description = "Backend URL to proxy to";
            };
            insecure = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Skip TLS verification for HTTPS backends";
            };
            targetTag = lib.mkOption {
              type = lib.types.str;
              description = "Tailscale ACL tag for the backend service (used for firewall grants)";
            };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client = {
      enable = true;
      tags = [ "ingress" ];
    };

    lab.services.ingress = {
      enable = true;
      inherit (cfg) virtualHosts;
    };
  };
}
