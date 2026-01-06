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
  };
in

{
  options.lab.services.gickup = {
    enable = lib.mkEnableOption "Gickup GitHub mirroring";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Systemd timer OnCalendar schedule for running gickup";
    };

    mirrorInterval = lib.mkOption {
      type = lib.types.str;
      default = "6h0m0s";
      description = "Interval for Gitea to pull changes from mirrored repos";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.gickup-github-token.file = ./github-token.age;
    age.secrets.gickup-gitea-token.file = ./gitea-token.age;

    systemd.services.gickup = {
      description = "Mirror GitHub repos to Gitea";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.gickup}/bin/gickup ${configFile}";
      };
    };

    systemd.timers.gickup = {
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
