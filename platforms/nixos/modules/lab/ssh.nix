{ config, lib, ... }:

let
  cfg = config.lab.ssh;
in

{
  options.lab.ssh = {
    enable = lib.mkEnableOption "Enable SSH access";

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        SSH keys which are allowed root access.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.root.openssh.authorizedKeys.keyFiles = cfg.authorizedKeys;

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };
  };
}
