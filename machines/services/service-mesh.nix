{ nodes, config, lib, pkgs, ... }:

# service-mesh
#
# Configures HashiCorp Consul and automatically federates with all other
# machines that enable the service mesh.

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.services.service-mesh;
  myHostName = config.networking.hostName;
  shouldFederate = node:
    node.config.services.service-mesh.enable && node.config.networking.hostName
    != myHostName;

  federationTargets = builtins.map (node: node.config.networking.fqdn)
    (builtins.filter shouldFederate (builtins.attrValues nodes));

in {
  options.services.service-mesh = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Run Consul as part of a cluster";
    };

    iface = mkOption {
      type = types.str;
      default = "eth0";
      description = "Which network interface to bind to";
    };
  };

  config = with lib; {
    services.consul = mkIf cfg.enable {
      enable = true;
      forceIpv4 = true;
      interface.bind = cfg.iface;
      package = unstable.consul;

      extraConfig = {
        server = true;
        connect = { enabled = true; };
        retry_join = federationTargets;
        bootstrap_expect = (builtins.length federationTargets) + 1;
        ports = { grpc = 8502; };
      };
    };

    networking.firewall.allowedTCPPortRanges = mkIf cfg.enable [
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

    networking.firewall.allowedUDPPortRanges = mkIf cfg.enable [
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
