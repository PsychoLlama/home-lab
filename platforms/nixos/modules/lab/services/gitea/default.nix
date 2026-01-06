{
  config,
  lib,
  ...
}:

let
  cfg = config.lab.services.gitea;
in

{
  options.lab.services.gitea = {
    enable = lib.mkEnableOption "Gitea self-hosted Git service";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/gitea";
      description = "Directory where Gitea stores data";
    };

    acl.tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "gitea";
      description = "Tailscale ACL tag for this service";
    };

    http.port = lib.mkOption {
      type = lib.types.port;
      readOnly = true;
      default = 3000;
      description = "HTTP port for Gitea web interface";
    };

    ssh.port = lib.mkOption {
      type = lib.types.port;
      readOnly = true;
      default = 2222;
      description = "SSH port for Git operations";
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ cfg.acl.tag ];

    services.gitea = {
      enable = true;
      stateDir = cfg.dataDir;
      database.type = "sqlite3";

      settings = {
        server = {
          DOMAIN = "gitea.${config.lab.domain}";
          ROOT_URL = "https://gitea.${config.lab.domain}/";
          HTTP_ADDR = "0.0.0.0";
          HTTP_PORT = cfg.http.port;
          START_SSH_SERVER = true;
          SSH_PORT = cfg.ssh.port;
          SSH_LISTEN_HOST = "0.0.0.0";
        };

        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = true;
        };

        session.COOKIE_SECURE = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.ssh.port ];
  };
}
