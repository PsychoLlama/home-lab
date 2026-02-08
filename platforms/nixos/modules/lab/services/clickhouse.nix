{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.lab.services.clickhouse;
in

{
  options.lab.services.clickhouse = {
    enable = lib.mkEnableOption "ClickHouse database for personal data warehouse";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/clickhouse";
      description = "Directory for ClickHouse data (should be on ZFS)";
    };

    memory.limit = lib.mkOption {
      type = lib.types.str;
      default = "2000000000"; # 2GB in bytes
      description = "Maximum memory ClickHouse can use (in bytes)";
    };

    http.port = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "HTTP interface port (Grafana queries)";
    };

    native.port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Native TCP port (Vector ingestion)";
    };

    acl.tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "clickhouse";
      description = "Tailscale ACL tag for this service";
    };

    prometheus = {
      enable = lib.mkEnableOption "Prometheus metrics";
      port = lib.mkOption {
        type = lib.types.port;
        default = 9363;
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

    services.clickhouse = {
      enable = true;
      package = pkgs.clickhouse;

      serverConfig = {
        # Custom data directory (for ZFS persistence)
        path = cfg.dataDir;
        tmp_path = "${cfg.dataDir}/tmp";
        user_files_path = "${cfg.dataDir}/user_files";
        format_schema_path = "${cfg.dataDir}/format_schemas";

        # Network
        listen_host = "0.0.0.0"; # Secured by Tailscale ACL
        http_port = cfg.http.port;
        tcp_port = cfg.native.port;

        # Memory limit
        max_server_memory_usage = cfg.memory.limit;

        # Logging
        logger = {
          level = "information";
          log = "/var/log/clickhouse-server/clickhouse-server.log";
          errorlog = "/var/log/clickhouse-server/clickhouse-server.err.log";
          size = "100M";
          count = 3;
        };
      }
      // lib.optionalAttrs cfg.prometheus.enable {
        prometheus = {
          endpoint = "/metrics";
          port = cfg.prometheus.port;
          metrics = true;
          events = true;
          asynchronous_metrics = true;
        };
      };

      usersConfig = {
        users.default = {
          profile = "default";
          quota = "default";
          networks.ip = [ "::/0" ]; # All IPs (secured by Tailscale)
        };
      };
    };

    # Ensure data and log directories exist
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 clickhouse clickhouse -"
      "d ${cfg.dataDir}/tmp 0750 clickhouse clickhouse -"
      "d ${cfg.dataDir}/user_files 0750 clickhouse clickhouse -"
      "d ${cfg.dataDir}/format_schemas 0750 clickhouse clickhouse -"
      "d /var/log/clickhouse-server 0750 clickhouse clickhouse -"
    ];
  };
}
