{ lib, pkgs, config, ... }:

with lib;

let cfg = config.lab.shell;

in {
  options.lab.shell = {
    enable = mkEnableOption "Manage the system shell with Nushell";
  };

  config = mkIf cfg.enable {
    programs.nushell = {
      enable = true;
      package = pkgs.unstable.nushell;
      extraConfig = readFile ./config.nu;
      extraEnv = readFile ./env.nu;
    };
  };
}
