{
  config,
  lib,
  ...
}:

let
  cfg = config.lab.services.restic-server;
in
{
  options.lab.services.restic-server = {
    enable = lib.mkEnableOption "Restic REST server for network backups";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/restic";
      description = "Directory where backups are stored";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.restic-htpasswd = {
      file = ./restic-htpasswd.age;
      owner = "restic";
      group = "restic";
    };

    services.restic.server = {
      enable = true;
      dataDir = cfg.dataDir;
      appendOnly = true;
      privateRepos = true;
      listenAddress = "8000";
      extraFlags = [
        "--htpasswd-file"
        config.age.secrets.restic-htpasswd.path
      ];
    };
  };
}
