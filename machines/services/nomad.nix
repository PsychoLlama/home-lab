{ nodes, config, lib, pkgs, ... }:

# container-orchestration
#
# Configures HashiCorp Nomad in server mode, automatically set to federate
# with other nomad instances discovered over Consul.

with lib;

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.nomad;
  nomadServers = attrValues
    (filterAttrs (_: node: with node.config.lab.nomad; enable && server.enable)
      nodes);

in {
  options.lab.nomad = {
    enable = mkEnableOption "Run Nomad as part of a cluster";
    server.enable = mkEnableOption "Orchestrate workloads for Nomad clients";
    client.enable = mkOption {
      type = types.bool;
      description = "Accept workloads from Nomad servers";
      default = true;
    };
  };

  config = {
    services.nomad = mkIf cfg.enable {
      enable = true;
      dropPrivileges = false;
      package = unstable.nomad;

      # Provides network support for the Consul sidecar proxy.
      extraPackages = with unstable; [ cni-plugins consul ];

      settings = {
        server = {
          enabled = cfg.server.enable;
          bootstrap_expect = length nomadServers;
        };

        client = {
          enabled = cfg.client.enable;
          cni_path = "${unstable.cni-plugins}/bin";

          servers =
            forEach nomadServers (server: server.config.networking.fqdn);

          # Force downgrade Envoy. See:
          # https://github.com/envoyproxy/envoy/issues/15235
          meta = { "connect.sidecar_image" = "envoyproxy/envoy:v1.16.4"; };
        };

        consul = {
          address = "127.0.0.1:8500";
          grpc_address = "127.0.0.1:8502";
        };
      };
    };

    networking.firewall.allowedTCPPortRanges = mkIf cfg.enable [
      # HTTP API
      {
        from = 4646;
        to = 4646;
      }

      # Private RPC
      {
        from = 4647;
        to = 4647;
      }

      # Serf WAN
      {
        from = 4648;
        to = 4648;
      }

      # Dynamic port allocations
      {
        from = 20000;
        to = 32000;
      }
    ];

    networking.firewall.allowedUDPPortRanges = mkIf cfg.enable [
      # Serf WAN
      {
        from = 4648;
        to = 4648;
      }

      # Dynamic port allocations
      {
        from = 20000;
        to = 32000;
      }
    ];
  };
}