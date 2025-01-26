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

  config = lib.mkIf cfg.enable {
    lab.services.vpn.server = {
      enable = true;

      url = "http://${config.networking.hostName}.host.${datacenter}.${domain}:${toString port}";
      dns.zone = "${datacenter}.vpn.${domain}";
      openFirewall = true;

      listen = {
        address = "0.0.0.0";
        port = 8080;
      };
    };

    # Experimental: Expose the VPN server through a Cloudflare Tunnel.
    # TODO: Move this to a separate module and route services by VPN/ACL.
    services.cloudflared = {
      enable = true;

      # Depends on Cloudflare for TLS termination. This is a security risk,
      # but considering the reputational damage to Cloudflare if they MITM'd
      # it, it's low on my list of concerns.
      #
      # NOTE: The default certificate only works for immediate subdomains.
      tunnels.vpn = {
        credentialsFile = config.age.secrets.vpn-tunnel-key.path;
        default = "http_status:404";
        ingress = {
          "vpn.${domain}" = {
            service = "http://localhost:${toString port}";
          };
        };
      };
    };

    age.secrets.vpn-tunnel-key = {
      file = ./vpn-tunnel-key.age;
      group = config.services.cloudflared.group;
      owner = config.services.cloudflared.user;
    };
  };
}
