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

      virtualHosts.grafana = {
        serverName = "grafana.selfhosted.city";
        backend = "rpi4-002:3000";
        targetTag = "monitoring";
      };

      virtualHosts.syncthing = {
        serverName = "syncthing.selfhosted.city";
        backend = "nas-001:8384";
        targetTag = "nas";
      };

      virtualHosts.restic = {
        serverName = "restic.selfhosted.city";
        backend = "nas-001:8000";
        targetTag = "nas";
      };

      virtualHosts.home = {
        serverName = "home.selfhosted.city";
        backend = "rpi4-002:8123";
        targetTag = "home-automation";
      };

      virtualHosts.unifi = {
        serverName = "unifi.selfhosted.city";
        backend = "https://rpi4-001:8443";
        targetTag = "router";
        insecure = true;
      };

      virtualHosts.ntfy = {
        serverName = "ntfy.selfhosted.city";
        backend = "rpi4-002:2586";
        targetTag = "ntfy";
        streaming = true;
      };
    };
  };
}
