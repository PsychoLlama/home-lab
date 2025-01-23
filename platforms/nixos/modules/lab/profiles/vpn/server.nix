{ config, lib, ... }:

let
  inherit (config.lab) datacenter domain;
  cfg = config.lab.profiles.vpn.server;
  port = 8080;
in

{
  options.lab.profiles.vpn.server = {
    enable = lib.mkEnableOption ''
      Use the Headscale VPN coordination server.

      Work in progress.

      This provides automatic DNS and ACLs restricting privileged lab services
      to authorized clients.
    '';
  };

  config = lib.mkIf cfg.enable {
    services.headscale = {
      enable = true;
      settings = {
        server_url = "http://${config.networking.hostName}.host.${datacenter}.${domain}:${toString port}";
        listen_addr = "0.0.0.0:${toString port}";
        dns.base_domain = "vpn.${datacenter}.${domain}";

        # TODO: Define ACLs.
      };
    };

    networking.firewall.allowedTCPPorts = [ port ];
  };
}
