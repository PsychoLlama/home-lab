{
  nodes,
  config,
  lib,
  ...
}:

# WIP: Playing around with Grafana's observability tools.

let
  cfg = config.lab.stacks.observability;
in

{
  options.lab.stacks.observability = {
    enable = lib.mkEnableOption "Enable observability services";
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ "monitoring" ];

    services = {
      prometheus = {
        enable = true;
        retentionTime = "1y";
        port = 9090;

        globalConfig = {
          scrape_interval = "15s";
          scrape_timeout = "10s";
          evaluation_interval = "30s";
        };

        # TODO: Make this a preset. Generate scrapers.
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

        settings.server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
        };

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
