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

  # Find all nodes with Syncthing enabled
  syncthingTargets = lib.pipe nodes [
    (lib.filterAttrs (_: node: node.config.services.syncthing.enable))
    (lib.mapAttrsToList (
      name: _: {
        targets = [ "${name}:8384" ];
        labels.instance = name;
      }
    ))
  ];

  # Find all nodes with Caddy ingress enabled and metrics exposed
  caddyTargets = lib.pipe nodes [
    (lib.filterAttrs (
      _: node:
      node.config.lab.services.ingress.enable && node.config.lab.services.ingress.prometheus.enable
    ))
    (lib.mapAttrsToList (
      name: _: {
        targets = [ "${name}:2019" ];
        labels.instance = name;
      }
    ))
  ];

  # Find all nodes with etcd discovery server enabled
  etcdTargets = lib.pipe nodes [
    (lib.filterAttrs (_: node: node.config.lab.services.discovery.server.enable))
    (lib.mapAttrsToList (
      name: _: {
        targets = [ "${name}:2379" ];
        labels.instance = name;
      }
    ))
  ];

  # Find all nodes with Kea DHCP metrics enabled
  keaTargets = lib.pipe nodes [
    (lib.filterAttrs (
      _: node: node.config.lab.services.dhcp.enable && node.config.lab.services.dhcp.prometheus.enable
    ))
    (lib.mapAttrsToList (
      name: node: {
        targets = [ "${name}:${toString node.config.lab.services.dhcp.prometheus.port}" ];
        labels.instance = name;
      }
    ))
  ];

  # Find all nodes with ntfy metrics enabled
  ntfyTargets = lib.pipe nodes [
    (lib.filterAttrs (
      _: node: node.config.lab.services.ntfy.enable && node.config.lab.services.ntfy.prometheus.enable
    ))
    (lib.mapAttrsToList (
      name: node: {
        targets = [ "${name}:${toString node.config.lab.services.ntfy.prometheus.port}" ];
        labels.instance = name;
      }
    ))
  ];
in

{
  options.lab.stacks.observability = {
    enable = lib.mkEnableOption "Enable observability services";

    acl.tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "monitoring";
      description = "Tailscale ACL tag for this stack";
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ cfg.acl.tag ];

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

          {
            job_name = "syncthing";
            static_configs = syncthingTargets;
          }

          {
            job_name = "caddy";
            static_configs = caddyTargets;
          }

          {
            job_name = "etcd";
            static_configs = etcdTargets;
          }

          {
            job_name = "kea";
            static_configs = keaTargets;
          }

          {
            job_name = "ntfy";
            static_configs = ntfyTargets;
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
