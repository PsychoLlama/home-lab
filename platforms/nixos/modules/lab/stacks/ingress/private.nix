{ config, lib, ... }:

let
  cfg = config.lab.stacks.ingress.private;
in

{
  options.lab.stacks.ingress.private = {
    enable = lib.mkEnableOption "private ingress stack (Caddy + VPN)";
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client = {
      enable = true;
      tags = [ "ingress" ];
    };

    lab.services.ingress = {
      enable = true;

      hosts."grafana.selfhosted.city" = {
        backend = "rpi4-002:3000";
        acl.tag = "monitoring";
      };

      hosts."syncthing.selfhosted.city" = {
        backend = "nas-001:8384";
        acl.tag = "nas";
      };

      hosts."restic.selfhosted.city" = {
        backend = "nas-001:8000";
        acl.tag = "nas";
      };

      hosts."home.selfhosted.city" = {
        backend = "rpi4-002:8123";
        acl.tag = "home-automation";
      };

      hosts."unifi.selfhosted.city" = {
        backend = "rpi4-001:8443";
        acl.tag = "router";
        tls.verify = false;
      };

      hosts."ntfy.selfhosted.city" = {
        backend = "rpi4-002:2586";
        acl.tag = "ntfy";
        streaming = true;
      };
    };
  };
}
