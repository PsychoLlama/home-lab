{
  lib,
  pkgs,
  config,
  ...
}:

let
  toml = pkgs.formats.toml { };
in
{
  options.lab.system = lib.mkOption {
    description = "Subcommands for the `system` administration command";
    type = toml.type;
    default = { };
  };

  config.clapfile = {
    enable = lib.mkDefault true;

    command = {
      name = "system";
      description = "System administration commands";
      subcommands = config.lab.system;
    };
  };
}
