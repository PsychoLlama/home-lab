{ pkgs, lib, config, options, ... }:

# Turns the device into a simple file server.

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.file-server;

in with lib; {
  options.lab.file-server = {
    enable = mkEnableOption "Act as a file server";
    hostId = options.networking.hostId;

    pools = mkOption {
      type = types.listOf types.str;
      description = ''
        Manages ZFS pools.
        Note: initialize them manually before you list them here.
      '';

      default = [ ];
    };

    mounts = mkOption {
      type = types.attrsOf types.str;

      description = ''
        Filesystem mounts for ZFS. Keys are file paths, values are datasets.
      '';

      example = { "/mnt/data" = "tank/data"; };

      default = { };
    };

    services.syncthing = filterAttrs (field: _:
      (all (filtered: field != filtered) [ "declarative" "useInotify" ]))
      options.services.syncthing;
  };

  config = mkIf cfg.enable {
    networking.hostId = cfg.hostId;

    boot = {
      supportedFilesystems = [ "zfs" ];
      zfs.requestEncryptionCredentials = cfg.pools;
    };

    services.zfs = {
      trim.enable = mkDefault true;

      autoSnapshot = {
        enable = mkDefault true;
        flags = mkDefault "-kp --utc";
      };

      autoScrub = {
        enable = mkDefault true;
        pools = mkDefault cfg.pools;
      };
    };

    fileSystems = mapAttrs (filePath: dataset: {
      device = dataset;
      fsType = "zfs";
      options = [ "zfsutil" ];
    }) cfg.mounts;

    # Containerized for a degree of isolation and security.
    containers.syncthing = with cfg.services;
      mkIf cfg.services.syncthing.enable {
        autoStart = true;

        bindMounts."/syncthing" = {
          hostPath = syncthing.dataDir;
          isReadOnly = false;
        };

        config = {
          # Containers are less likely to stick around than the host OS. If
          # the user or group ID changes, it could break the service, so
          # they're statically assigned here.
          users = {
            groups.filesync.gid = 8384;
            users.filesync = {
              isSystemUser = true;
              group = syncthing.group;
              uid = 8384;
            };
          };

          services.syncthing = syncthing // {
            # The original `dataDir` is the host path; This is the mount.
            dataDir = "/syncthing";

            # This is stored on the same dataset to leverage disk encryption.
            # The config includes identity files.
            configDir = "/syncthing/.config";

            # The NixOS service forces an incremental UID/GID for the default
            # "syncthing" names. Overridden here for more control.
            user = "filesync";
            group = "filesync";
          };
        };
      };
  };
}
