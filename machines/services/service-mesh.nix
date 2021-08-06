{ nodes, config, lib, ... }:

# service-mesh
#
# Configures HashiCorp Consul and automatically federates with all other
# machines that enable the service mesh.

let
  cfg = config.services.service-mesh;
  tcpPorts = config.networking.allowedTCPPortRanges or [];
  udpPorts = config.networking.allowedUDPPortRanges or [];
  myHostName = config.networking.hostName;
  shouldFederate = node:
    node.config.services.service-mesh.enable &&
    node.config.networking.hostName != myHostName;

  federationTargets = builtins.map
    (node: node.config.networking.fqdn)
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
    fileSystems."/srv/consul" = mkIf cfg.enable {
      fsType = "nfs";
      device = "file-server.selfhosted.city:/mnt/zpool1/locker/applications/consul";
    };

    services.consul = mkIf cfg.enable {
      enable = true;
      interface.bind = cfg.iface;

      extraConfig = {
        server = true;
        data_dir = "/srv/consul/${myHostName}";
        retry_join = federationTargets;
        bootstrap_expect = (builtins.length federationTargets) + 1;
      };
    };

    networking.firewall.allowedTCPPortRanges = mkIf cfg.enable (tcpPorts ++ [
      { from = 8600; to = 8600; } # DNS
      { from = 8500; to = 8500; } # HTTP
      { from = 8300; to = 8300; } # Server-to-server RPC
      { from = 8301; to = 8302; } # LAN/WAN Serf
      { from = 21000; to = 21255; } # Sidecar proxy
    ]);

    networking.firewall.allowedUDPPortRanges = mkIf cfg.enable (udpPorts ++ [
      { from = 8600; to = 8600; } # DNS
      { from = 8301; to = 8302; } # LAN/WAN Serf
    ]);
  };
}
