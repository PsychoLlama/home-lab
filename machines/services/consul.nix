{ nodes, config, lib, pkgs, ... }:

with lib;

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.consul;

  expectedServerCount = length (attrValues
    (filterAttrs (_: node: node.config.lab.consul.server.enable) nodes));

in {
  options.lab.consul = {
    enable = mkEnableOption "Run Consul as part of a cluster";
    interface = mkOption {
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
      interface.bind = cfg.interface;
      package = unstable.consul;
      webUi = true;

      extraConfig = {
        inherit (import ../config.nix) domain datacenter;
        server = cfg.server.enable;
        connect.enabled = true;
        ports.grpc = 8502;
        retry_join = [ "consul.service.selfhosted.city" ];
        addresses = {
          http = "0.0.0.0";
          dns = "0.0.0.0";
        };
      } // (optionalAttrs cfg.server.enable {
        bootstrap_expect = expectedServerCount;
      });
    };

    networking.firewall = {
      allowedTCPPorts = [
        8600 # DNS
        8500 # HTTP API
        8502 # gRPC API
        8300 # Server-to-server RPC
        8301 # LAN Serf
        8302 # WAN Serf
      ];

      allowedUDPPorts = [
        8600 # DNS
        8301 # LAN Serf
        8302 # WAN Serf
      ];

      # Sidecar proxy
      allowedTCPPortRanges = [{
        from = 21000;
        to = 21255;
      }];
    };
  };
}
