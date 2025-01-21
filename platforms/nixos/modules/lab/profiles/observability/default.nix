{
  nodes,
  config,
  lib,
  pkgs,
  ...
}:

# WIP: Playing around with Grafana's observability tools.

let
  cfg = config.lab.profiles.observability;
in

{
  options.lab.profiles.observability = {
    enable = lib.mkEnableOption "Enable observability services";
  };

  config = lib.mkIf cfg.enable {
    services = {
      prometheus = {
        enable = true;
        package = pkgs.unstable.prometheus;
        retentionTime = "1y";
        port = 9090;

        globalConfig = {
          scrape_interval = "15s";
          scrape_timeout = "10s";
          evaluation_interval = "30s";
        };

        exporters.node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9100;
        };

        scrapeConfigs = [
          {
            job_name = "prometheus";
            static_configs = [
              {
                targets = [ "localhost:9090" ];
                labels = {
                  instance = "prometheus";
                };
              }
            ];
          }

          {
            job_name = "coredns";
            static_configs = [
              {
                targets = [ "${nodes.rpi4-001.config.networking.fqdn}:9153" ];
                labels = {
                  instance = "coredns";
                };
              }
            ];
          }

          {
            job_name = "node";
            static_configs = [
              {
                targets = [ "localhost:9100" ];
                labels = {
                  instance = "localhost";
                };
              }
            ];
          }
        ];
      };

      grafana = {
        enable = true;
        package = pkgs.unstable.grafana;

        provision = {
          enable = true;
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:9090";
            }
          ];
        };
      };
    };
  };
}
