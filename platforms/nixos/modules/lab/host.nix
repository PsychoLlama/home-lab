{ config, lib, ... }:

# Exposes all the configuration options for the host. This is particularly
# useful for the network address.

let
  inherit (lib) types mkOption;
  cfg = config.lab.host;
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

    # Option names mirror `config.nix.buildMachines`.
    builder = {
      enable = lib.mkEnableOption "Use this machine as a remote builder";

      uri = mkOption {
        type = types.str;
        description = "URI for the remote builder";
        default = "ssh://${cfg.builder.sshUser}@${cfg.builder.hostName}";
      };

      hostName = mkOption {
        type = types.str;
        description = "The hostname of the remote builder";
        default = config.networking.fqdn;
      };

      systems = mkOption {
        type = types.listOf (types.enum lib.systems.doubles.all);
        description = "Systems supported by the builder";
        default = [ cfg.system ];
      };

      sshUser = mkOption {
        type = types.str;
        description = "The username to log in as";
        default = "root";
      };

      sshKey = mkOption {
        type = types.str;
        description = ''
          The path to the SSH private key with which to authenticate on the
          build machine.
        '';

        # TODO: Find a better way to do this.
        default = "/root/.ssh/home_lab";
      };

      supportedFeatures = mkOption {
        type = types.listOf types.str;
        description = "System features supported by the builder";
        default = [ ];
      };

      maxJobs = mkOption {
        type = types.int;
        description = "Maximum number of jobs to run in parallel";
        default = 4;
      };

      speedFactor = mkOption {
        type = types.int;
        description = "Speed factor for the builder";
        default = 1;
      };

      conf = mkOption {
        readOnly = true;
        description = ''
          Generated parameters for Nix to configure a remote builder. See:
          https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html
        '';

        default = lib.concatStringsSep " " [
          cfg.builder.uri
          (lib.concatStringsSep "," cfg.builder.systems)
          cfg.builder.sshKey
          (toString cfg.builder.maxJobs)
          (toString cfg.builder.speedFactor)
          (lib.concatStringsSep "," cfg.builder.supportedFeatures)
        ];
      };
    };
  };
}
