{ nodes, config, lib, pkgs, ... }:

with lib;

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.nomad;

  expectedServerCount = length (attrValues
    (filterAttrs (_: node: node.config.lab.nomad.server.enable) nodes));

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

  config = mkIf cfg.enable {
    services.nomad = {
      enable = true;
      dropPrivileges = false;
      package = unstable.nomad;

      # Provides network support for the Consul sidecar proxy.
      extraPackages = with unstable; [ cni-plugins consul ];

      settings = {
        server = {
          enabled = cfg.server.enable;
          bootstrap_expect = expectedServerCount;
        };

        client = {
          enabled = cfg.client.enable;
          cni_path = "${unstable.cni-plugins}/bin";
          servers = [ "nomad.service.selfhosted.city" ];

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

    networking.firewall = {
      allowedTCPPorts = [
        4646 # HTTP API
        4647 # Private RPC
        4648 # Serf WAN
      ];

      allowedUDPPorts = [
        4648 # Serf WAN
      ];

      # Dynamic port allocations
      allowedTCPPortRanges = [{
        from = 20000;
        to = 32000;
      }];

      # Dynamic port allocations
      allowedUDPPortRanges = [{
        from = 20000;
        to = 32000;
      }];
    };

    # Nomad tightly integrates with Consul and strongly discourages use over
    # the network; It must run locally.
    lab.consul.enable = mkDefault cfg.client.enable;
  };
}
