{ config, lib, ... }:

# Exposes all the configuration options for the host. This is particularly
# useful for the network address.

let
  inherit (lib) types mkOption;
in

{
  options.lab.host = {
    interface = mkOption {
      type = types.nullOr types.str;
      example = "eth0";
      description = "Name of the primary network interface";
      default = null;
    };

    ip4 = mkOption {
      type = types.str;
      example = "192.168.1.10";
      description = "IPv4 address for the primary network interface";
    };

    system = mkOption {
      type = types.enum lib.systems.doubles.all;
      example = "aarch64-linux";
      description = "Architecture identifier of the host system";
    };

    profile = mkOption {
      type = types.deferredModule;
      description = "Module for hardware-specific configuration";
      default = { };
    };

    module = mkOption {
      type = types.deferredModule;
      description = "Module for host-specific configuration";
    };

    publicKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Public keys associated with this host";
    };
  };
}
