{ config, lib, ... }:

let
  cfg = config.lab.stacks.ingress;
in

{
  options.lab.stacks.ingress = {
    enable = lib.mkEnableOption "ingress stack (Caddy + VPN)";

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          serverName = lib.mkOption {
            type = lib.types.str;
            description = "FQDN for this virtual host";
          };
          backend = lib.mkOption {
            type = lib.types.str;
            description = "Backend URL to proxy to";
          };
        };
      });
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
