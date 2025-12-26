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
  };

  config.services.prometheus.exporters.node = lib.mkIf cfg.enable {
    enable = true;
    enabledCollectors = cfg.collectors;
    port = 9100;
  };
}
