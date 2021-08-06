{ nodes, config, lib, ... }:

# service-mesh
#
# Configures HashiCorp Consul and automatically federates with other machines
# that enable the service mesh (TODO).

let
  cfg = config.services.service-mesh;

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
    fileSystems."/var/db/consul" = mkIf cfg.enable {
      fsType = "nfs";
      device = "file-server.selfhosted.city:/mnt/zpool1/locker/applications/consul";
    };

    services.consul = mkIf cfg.enable {
      enable = true;
      interface.bind = cfg.iface;

      extraConfig = {
        data_dir = "/var/db/consul/${config.networking.hostName}";
      };
    };
  };
}
