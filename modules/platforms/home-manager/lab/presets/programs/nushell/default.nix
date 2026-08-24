{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.lab.presets.programs.nushell;
in

{
  options.lab.presets.programs.nushell = {
    enable = lib.mkEnableOption "Use nushell";
  };

  config.programs.nushell = lib.mkIf cfg.enable {
    enable = true;
    package = pkgs.unstable.nushell;
    extraConfig = lib.readFile ./config.nu;
    extraEnv = lib.readFile ./env.nu;

    libraries = {
      enable = true;
      path = [
        (lib.fileset.toSource {
          root = ./libraries;
          fileset = ./libraries;
        })
      ];
    };
  };
}
