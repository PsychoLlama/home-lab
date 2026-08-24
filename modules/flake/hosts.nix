{ config, lib, ... }:

# The machines this flake manages. Each host contributes its own entry from
# `modules/hosts/`, and `colmena.nix` turns them into deployable nodes.

let
  inherit (lib) mkOption types;
in

{
  options.lab.hosts = mkOption {
    description = "Machines in the home lab, keyed by hostname.";
    default = { };

    type = types.attrsOf (
      types.submodule (
        { name, ... }:

        {
          options = {
            name = mkOption {
              type = types.str;
              readOnly = true;
              default = name;
              description = "The machine's hostname.";
            };

            system = mkOption {
              type = types.enum config.systems;
              example = "aarch64-linux";
              description = "Architecture identifier of the host system.";
            };

            ip4 = mkOption {
              type = types.str;
              example = "192.168.1.10";
              description = "IPv4 address for the primary network interface.";
            };

            interface = mkOption {
              type = types.nullOr types.str;
              example = "eth0";
              default = null;
              description = "Name of the primary network interface.";
            };

            publicKeys = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Public keys associated with this host.";
            };

            profile = mkOption {
              type = types.deferredModule;
              default = { };
              description = "Module for hardware-specific configuration.";
            };

            module = mkOption {
              type = types.deferredModule;
              description = "Module for host-specific configuration.";
            };
          };
        }
      )
    );
  };
}
