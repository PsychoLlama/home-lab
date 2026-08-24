{ config, lib, ... }:

let
  cfg = config.lab.services.node-exporter;
in

{
  options.lab.services.node-exporter = {
    enable = lib.mkEnableOption "Prometheus node exporter";

    collectors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "systemd" ];
      description = "Additional collectors to enable";
    };

    prometheus = {
      port = lib.mkOption {
        type = lib.types.int;
        readOnly = true;
        default = 9100;
        description = "Port for node exporter metrics";
      };
      acl.tag = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "lab";
        description = "Tailscale ACL tag for monitoring access (all lab nodes)";
      };
    };
  };

  config.services.prometheus.exporters.node = lib.mkIf cfg.enable {
    enable = true;
    enabledCollectors = cfg.collectors;
    port = 9100;
  };
}
