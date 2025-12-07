{ lib, config, ... }:

let
  cfg = config.lab.stacks.fancy-shell;
in

{
  options.lab.stacks.fancy-shell = {
    enable = lib.mkEnableOption "Configure a fancy login shell";
  };

  config.lab.presets = lib.mkIf cfg.enable {
    programs = {
      nushell.enable = lib.mkDefault true;
      starship.enable = lib.mkDefault true;
    };
  };
}
