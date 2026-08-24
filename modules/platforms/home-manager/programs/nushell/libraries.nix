{ config, lib, ... }:

let
  inherit (lib) types;
  cfg = config.programs.nushell.libraries;
in

{
  options.programs.nushell.libraries = {
    enable = lib.mkEnableOption "Manage the library search path";
    path = lib.mkOption {
      type = types.listOf (types.either types.str types.path);
      description = "Libraries visible in the search path";
      default = [ ];
    };
  };

  config.programs.nushell = lib.mkIf cfg.enable {
    extraEnv = ''
      ### Add custom libraries to the search path ###
      $env.NU_LIB_DIRS ++= ${lib.hm.nushell.toNushell { } (lib.map toString cfg.path)}
    '';
  };
}
