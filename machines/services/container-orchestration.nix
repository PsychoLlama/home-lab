{ nodes, config, lib, pkgs, ... }:

# container-orchestration
#
# Configures HashiCorp Nomad in server mode, automatically set to federate
# with other nomad instances discovered over Consul.

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.services.container-orchestration;
  runsNomad = node: node.config.services.container-orchestration.enable;

  nomadClusterCount =
    builtins.length (builtins.filter runsNomad (builtins.attrValues nodes));

in {
  options.services.container-orchestration = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Run Nomad as part of a cluster";
    };
  };

  config = with lib; {
    services.nomad = mkIf cfg.enable {
      enable = true;
      dropPrivileges = false;
      package = unstable.nomad;

      # Provides network support for the Consul sidecar proxy.
      extraPackages = with pkgs; [ cni-plugins unstable.consul ];

      settings = {
        server = {
          enabled = true;
          bootstrap_expect = nomadClusterCount;
        };

        client = with pkgs; {
          enabled = true;
          cni_path = "${cni-plugins}/bin";
        };

        consul = { address = "127.0.0.1:8500"; };
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
