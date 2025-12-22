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

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = cfg.collectors;
      port = 9100;
    };

    # Allow monitoring hosts to scrape metrics
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ];
  };
}
