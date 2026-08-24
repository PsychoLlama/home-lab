{ lib, ... }:

# Hardware-specific NixOS modules, one per board. Hosts pick one through
# `lab.hosts.<name>.profile`.

{
  imports = [
    ./cm3588.nix
    ./raspberry-pi-4.nix
  ];

  options.lab.deviceProfiles = lib.mkOption {
    type = lib.types.attrsOf lib.types.deferredModule;
    default = { };
    description = "Hardware profiles, keyed by device model.";
  };
}
