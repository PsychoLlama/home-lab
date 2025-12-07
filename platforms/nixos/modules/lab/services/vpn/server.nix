{ config, lib, ... }:

let
  cfg = config.lab.services.vpn.server;
in

{
  options.lab.services.vpn.server = {
    enable = lib.mkEnableOption ''
      Use the Headscale VPN coordination server.

      This provides automatic DNS and ACLs restricting privileged lab services
      to authorized clients.
    '';

    url = lib.mkOption {
      type = lib.types.str;
      description = ''
        Advertised URL that VPN clients can reach.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open the firewall to allow traffic to the VPN server.
      '';
    };

    listen = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = ''
          Address to listen on.
        '';
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 8080;
        description = ''
          Port to listen on.
        '';
      };
    };

    dns.zone = lib.mkOption {
      type = lib.types.str;
      default = "vpn.internal";
      description = ''
        Domain under which hostnames are resolved. Every VPN client shows up
        here indexed by hostname.
      '';
    };

    dns.nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ config.lab.networks.datacenter.ipv4.gateway ];
      description = ''
        DNS servers advertised to VPN clients for resolving non-MagicDNS
        queries. Required when MagicDNS is enabled (the default).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.listen.port ];
    deployment.tags = [ "vpn" ];

    services.headscale = {
      enable = true;
      settings = {
        server_url = cfg.url;
        listen_addr = "${cfg.listen.address}:${toString cfg.listen.port}";
        dns = {
          base_domain = cfg.dns.zone;
          nameservers.global = cfg.dns.nameservers;
        };
        logtail.enabled = lib.mkDefault true;
      };
    };
  };
}
