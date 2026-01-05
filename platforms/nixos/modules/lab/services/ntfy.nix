{ config, lib, ... }:

let
  cfg = config.lab.services.ntfy;
  port = 2586;
in

{
  options.lab.services.ntfy = {
    enable = lib.mkEnableOption "ntfy-sh push notification server";

    acl.tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "ntfy";
      description = "Tailscale ACL tag for this service";
    };

    prometheus = {
      enable = lib.mkEnableOption "Expose Prometheus metrics";
      port = lib.mkOption {
        type = lib.types.port;
        default = 9095;
        description = "Port for the Prometheus metrics endpoint";
      };
      acl.tag = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = cfg.acl.tag;
        description = "Tailscale ACL tag for monitoring access (derived from service acl.tag)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ cfg.acl.tag ];

    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://ntfy.${config.lab.domain}";
        listen-http = "0.0.0.0:${toString port}";
      }
      // lib.optionalAttrs cfg.prometheus.enable {
        enable-metrics = true;
        metrics-listen-http = "0.0.0.0:${toString cfg.prometheus.port}";
      };
    };
  };
}
