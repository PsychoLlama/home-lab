{ nodes, config, lib, pkgs, ... }:

with lib;

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.nomad;

  expectedServerCount = length (attrValues
    (filterAttrs (_: node: node.config.lab.nomad.server.enable) nodes));

  key = file: {
    user = "nomad";
    group = "nomad";
    permissions = "440";
    text = builtins.readFile file;
  };

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
    deployment.keys = {
      nomad-tls-cert = key ../../nomad.cert;
      nomad-tls-key = key ../../nomad.key;
    };

    # Without this, the Nomad CLI will attempt API calls over insecure HTTP.
    environment.variables.NOMAD_ADDR =
      "https://nomad.service.lab.selfhosted.city:4646";

    services.nomad = {
      enable = true;
      package = unstable.nomad;

      # Provides network support for the Consul sidecar proxy.
      extraPackages = with unstable; [ cni-plugins consul ];

      settings = {
        inherit (import ../config.nix) datacenter;

        server = {
          enabled = cfg.server.enable;
          bootstrap_expect = expectedServerCount;
        };

        client = {
          enabled = cfg.client.enable;
          cni_path = "${unstable.cni-plugins}/bin";
          servers = [ "nomad.service.lab.selfhosted.city" ];

          # Force downgrade Envoy. See:
          # https://github.com/envoyproxy/envoy/issues/15235
          meta = { "connect.sidecar_image" = "envoyproxy/envoy:v1.16.4"; };
        };

        consul = {
          address = "127.0.0.1:8500";
          grpc_address = "127.0.0.1:8502";
        };

        tls = {
          rpc = true;
          http = true;

          ca_file = "/etc/ssl/certs/home-lab.crt";
          cert_file = "/run/keys/nomad-tls-cert";
          key_file = "/run/keys/nomad-tls-key";
        };
      };
    };

    systemd.services.nomad = {
      serviceConfig.SupplementaryGroups = mkForce [ "docker" "keys" ];
      after = [ "nomad-tls-cert-key.service" "nomad-tls-key-key.service" ];
      wants = [ "nomad-tls-cert-key.service" "nomad-tls-key-key.service" ];
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
