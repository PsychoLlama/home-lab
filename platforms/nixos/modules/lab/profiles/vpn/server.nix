{ config, lib, ... }:

let
  inherit (config.lab) datacenter domain;
  inherit (config.lab.services.vpn.server.listen) port;
  cfg = config.lab.profiles.vpn.server;
in

{
  options.lab.profiles.vpn.server = {
    enable = lib.mkEnableOption ''
      Run a VPN server on this host.
    '';
  };

  config.lab.services.vpn.server = lib.mkIf cfg.enable {
    enable = true;

    url = "http://${config.networking.hostName}.host.${datacenter}.${domain}:${toString port}";
    dns.zone = "${datacenter}.vpn.${domain}";
    openFirewall = true;

    listen = {
      address = "0.0.0.0";
      port = 8080;
    };
  };
}
