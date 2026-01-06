{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.lab.services.gickup;
  yaml = pkgs.formats.yaml { };

  configFile = yaml.generate "gickup.yml" {
    cron = cfg.cron;

    source.github = [
      {
        token_file = config.age.secrets.gickup-github-token.path;
        exclude = [ ];
      }
    ];

    destination.gitea = [
      {
        url = "https://gitea.${config.lab.domain}";
        token_file = config.age.secrets.gickup-gitea-token.path;
        createorg = true;
        mirror = {
          enabled = true;
          mirrorinterval = cfg.mirrorInterval;
        };
        visibility = {
          repositories = "private";
          organizations = "private";
        };
      }
    ];

    metrics.prometheus = {
      listen_addr = ":${toString cfg.prometheus.port}";
      endpoint = "/metrics";
    };
  };
in

{
  options.lab.services.gickup = {
    enable = lib.mkEnableOption "Gickup GitHub mirroring";

    cron = lib.mkOption {
      type = lib.types.str;
      default = "0 0 * * *";
      description = "Cron schedule for sync (standard 5-field format)";
    };

    mirrorInterval = lib.mkOption {
      type = lib.types.str;
      default = "6h0m0s";
      description = "Interval for Gitea to pull changes from mirrored repos";
    };

    prometheus = {
      port = lib.mkOption {
        type = lib.types.port;
        readOnly = true;
        default = 6178;
        description = "Port for the Prometheus metrics endpoint";
      };

      acl.tag = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "gickup";
        description = "Tailscale ACL tag for monitoring access";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ cfg.prometheus.acl.tag ];

    age.secrets.gickup-github-token.file = ./github-token.age;
    age.secrets.gickup-gitea-token.file = ./gitea-token.age;

    systemd.services.gickup = {
      description = "Mirror GitHub repos to Gitea";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.gickup}/bin/gickup ${configFile}";
        Restart = "on-failure";
      };
    };
  };
}
