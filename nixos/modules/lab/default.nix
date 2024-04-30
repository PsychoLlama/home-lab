{ lib, ... }:

with lib;

{
  imports = [
    ./filesystems
    ./host.nix
    ./networks.nix
    ./profiles
    ./services
    ./system.nix
  ];

  # A place to store constants. These should be set for every host. Not all
  # hosts need the same config, for example hosts in different datacenters may
  # have different configurations.
  options.lab = {
    domain = mkOption {
      type = types.str;
      example = "internal.cloud";
      description = "Top-level domain for all hosts and datacenters";
    };

    datacenter = mkOption {
      type = types.str;
      example = "garage";
      description = "Name of the datacenter. This becomes a subdomain.";
    };
  };
}
