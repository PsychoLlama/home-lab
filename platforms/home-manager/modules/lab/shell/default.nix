{
  lib,
  pkgs,
  config,
  ...
}:

with lib;

let
  cfg = config.lab.shell;
in
{
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

    programs.starship = {
      enable = true;
      package = pkgs.unstable.starship;
      enableNushellIntegration = true;

      settings = {
        add_newline = false;

        ### LEFT SIDE ###
        format = concatStrings [
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
  };
}
