{ lib, ... }:

{
  imports = [
    ./cidr.nix
  ];

  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Utilities shared across the lab, one namespace per file.";
  };
}
