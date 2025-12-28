{
  nodes,
  config,
  lib,
  ...
}:

let
  cfg = config.lab.stacks.observability;

  # Find all nodes with node-exporter enabled
  nodeExporterTargets = lib.pipe nodes [
    (lib.filterAttrs (_: node: node.config.lab.services.node-exporter.enable))
    (lib.mapAttrsToList (
      name: _: {
        targets = [ "${name}:9100" ];
        labels.instance = name;
      }
    ))
  ];

  # Find all nodes with DNS enabled
  dnsTargets = lib.pipe nodes [
    (lib.filterAttrs (_: node: node.config.lab.services.dns.enable))
    (lib.mapAttrsToList (
      name: _: {
        targets = [ "${name}:9153" ];
        labels.instance = name;
      }
    ))
  ];

  # Find all nodes with Home Assistant enabled
  homeAssistantTargets = lib.pipe nodes [
    (lib.filterAttrs (_: node: node.config.lab.stacks.home-automation.enable))
    (lib.mapAttrsToList (
      name: _: {
        targets = [ "${name}:8123" ];
        labels.instance = name;
      }
    ))
  ];
in

{
  options.lab.stacks.observability = {
    enable = lib.mkEnableOption "Enable observability services";
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ "monitoring" ];

    # Home Assistant API token for Prometheus scraping
    age.secrets.ha-prometheus-token = {
      file = ./ha-prometheus-token.age;
      owner = "prometheus";
      group = "prometheus";
    };

    services = {
      prometheus = {
        enable = true;
        checkConfig = "syntax-only"; # Skip credential file checks (runtime paths)
        retentionTime = "1y";
        port = 9090;

        globalConfig = {
          scrape_interval = "15s";
          scrape_timeout = "10s";
          evaluation_interval = "30s";
        };

        scrapeConfigs = [
          {
            job_name = "prometheus";
            static_configs = [
              {
                targets = [ "localhost:9090" ];
                labels.instance = "prometheus";
              }
            ];
          }

          {
            job_name = "coredns";
            static_configs = dnsTargets;
          }

          {
            job_name = "node";
            static_configs = nodeExporterTargets;
          }

          {
            job_name = "home-assistant";
            metrics_path = "/api/prometheus";
            authorization.credentials_file = config.age.secrets.ha-prometheus-token.path;
            static_configs = homeAssistantTargets;
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
