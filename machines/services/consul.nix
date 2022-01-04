{ nodes, config, lib, pkgs, ... }:

# Consul
#
# Configures HashiCorp Consul and automatically federates with all other
# machines that enable the service mesh.

with lib;

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.consul;
  myAddress = config.networking.fqdn;

  otherConsulServers = mapAttrsToList (_: node: node.config.networking.fqdn)
    (filterAttrs (_: node:
      node.config.lab.consul.server.enable && node.config.networking.fqdn
      != myAddress) nodes);

  expectedServerCount = length otherConsulServers
    + (if cfg.server.enable then 1 else 0);

in {
  options.lab.consul = {
    enable = mkEnableOption "Run Consul as part of a cluster";
    iface = mkOption {
      type = types.str;
      default = "eth0";
      description = "Which network interface to bind to";
    };

    server.enable = mkEnableOption "Run Consul in server mode";
  };

  config = mkIf cfg.enable {
    services.consul = {
      enable = true;
      forceIpv4 = true;
      interface.bind = cfg.iface;
      package = unstable.consul;
      webUi = true;

      extraConfig = {
        server = cfg.server.enable;
        connect.enabled = true;
        ports.grpc = 8502;
        addresses.http = "0.0.0.0";
        retry_join = [ "consul.service.selfhosted.city" ];
      } // (optionalAttrs cfg.server.enable {
        bootstrap_expect = expectedServerCount;
      });
    };

    networking.firewall.allowedTCPPortRanges = [
      # DNS
      {
        from = 8600;
        to = 8600;
      }

      # HTTP API
      {
        from = 8500;
        to = 8500;
      }

      # gRPC API
      {
        from = 8502;
        to = 8502;
      }

      # Server-to-server RPC
      {
        from = 8300;
        to = 8300;
      }

      # LAN/WAN Serf
      {
        from = 8301;
        to = 8302;
      }

      # Sidecar proxy
      {
        from = 21000;
        to = 21255;
      }
    ];

    networking.firewall.allowedUDPPortRanges = [
      # DNS
      {
        from = 8600;
        to = 8600;
      }

      # LAN/WAN Serf
      {
        from = 8301;
        to = 8302;
      }
    ];
  };
}
