{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.lab.presets.programs.starship;
in

{
  options.lab.presets.programs.starship = {
    enable = lib.mkEnableOption "Use starship prompt";
  };

  config.programs.starship = lib.mkIf cfg.enable {
    enable = true;
    package = pkgs.unstable.starship;
    enableNushellIntegration = true;

    settings = {
      add_newline = false;

      ### LEFT SIDE ###
      format = lib.concatStrings [
        "$env_var"
        "$hostname"
        " "
        "$directory"
        " "
        "$character"
      ];

      env_var.DATACENTER = {
        description = "Current datacenter";
        format = "[$env_value.]($style)";
        style = "dimmed white";
      };

      hostname = {
        ssh_only = false;
        ssh_symbol = "";
        format = "[$hostname]($style)";
        style = "white";
      };

      directory = {
        format = "[$path]($style)";
        truncation_length = 1;
        style = "blue";
      };

      ### RIGHT SIDE ###
      right_format = "$time";

      time = {
        format = "[$time]($style)";
        style = "dimmed white";
        utc_time_offset = "0";
        disabled = false;
      };
    };
  };
}
