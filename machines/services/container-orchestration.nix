{ nodes, config, lib, ... }:

# container-orchestration
#
# Configures HashiCorp Nomad in server mode, automatically set to federate
# with other nomad instances discovered over Consul.

let
  cfg = config.services.container-orchestration;
  runsNomad = node: node.config.services.service-mesh.enable;

  nomadClusterCount = builtins.length
    (builtins.filter runsNomad (builtins.attrValues nodes));

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

      settings = {
        server = {
          enabled = true;
          bootstrap_expect = nomadClusterCount;
        };

        client = {
          enabled = true;
        };

        consul = {
          address = "127.0.0.1:8500";
        };
      };
    };

    networking.firewall.allowedTCPPortRanges = mkIf cfg.enable [
      { from = 4646; to = 4646; } # HTTP API
      { from = 4647; to = 4647; } # Private RPC
      { from = 4648; to = 4648; } # Serf WAN
      { from = 20000; to = 32000; } # Dynamic port allocations
    ];

    networking.firewall.allowedUDPPortRanges = mkIf cfg.enable [
      { from = 4648; to = 4648; } # Serf WAN
      { from = 20000; to = 32000; } # Dynamic port allocations
    ];
  };
}
