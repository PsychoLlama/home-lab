{ lib, config, ... }:

let
  cfg = config.lab.stacks.host-defaults;
in

{
  options.lab.stacks.host-defaults = {
    enable = lib.mkEnableOption "Configure baseline defaults every host gets";
  };

  config.lab.presets = lib.mkIf cfg.enable {
    programs = {
      nushell.enable = lib.mkDefault true;
      starship.enable = lib.mkDefault true;
      tmux.enable = lib.mkDefault true;
    };
  };
}
