{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types mkOption concatMapStringsSep;

  cfg = config.lab.filesystems.zfs;

  # Example: "/mnt/tank" must be mounted before "/mnt/tank/library".
  # FS dependency order can be inferred by string length.
  topoSortedMounts = lib.pipe cfg.mounts [
    lib.attrsToList
    (lib.sortOn (mount: lib.stringLength mount.name))
    (map (mount: mount.name))
  ];

  hostId = lib.pipe config.networking.hostName [
    # Convert to a 32-bit hex string.
    (builtins.hashString "md5")

    # Split into a list of characters.
    (lib.splitString "")

    # Grab 32-bits of entropy (8 hex chars).
    (lib.take 9)

    # And back to a string.
    (lib.concatStrings)
  ];
in

{
  options.lab.filesystems.zfs = {
    enable = lib.mkEnableOption ''
      Mount and manage encrypted ZFS pools. This option changes the kernel and
      boot process. Reboot the machine after changing this option.

      Use `zfs-attach` and `zfs-detach` to decrypt/encrypt pools after boot.
      Services depending on ZFS datasets should wait on `zfs.decryption.target`.
    '';

    decryption = {
      name = mkOption {
        type = types.str;
        default = "zfs-decryption";
        description = ''
          Name of the systemd decryption target (no trailing ".target")
        '';
      };

      target = mkOption {
        type = types.str;
        default = "${cfg.decryption.name}.target";
        internal = true;
        description = "Name of the systemd decryption target";
      };
    };

    mounts = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        "/mnt/tank" = "tank";
      };
      description = "Mapping of mount points to ZFS datasets";
    };

    # Pool config is documentation. Create pools manually following the
    # structure defined here.
    pools = mkOption {
      default = { };
      description = ''
        Declarative pool/dataset configuration for documentation purposes.
        Pools must be created manually - see the file-server README.
      '';

      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options.name = mkOption {
              type = types.str;
              example = "tank";
              description = "Name of the ZFS pool";
              default = name;
            };

            options.properties = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = ''
                Mapping of ZFS filesystem props to apply. See `zfsprops(7)` for
                a list of available options.
              '';
            };

            options.vdevs = mkOption {
              default = [ ];
              type = types.listOf (
                types.submodule {
                  options.type = mkOption {
                    type = types.nullOr types.str;
                    example = "mirror";
                    default = null;
                    description = ''
                      Type of virtual device. See `zpoolconcepts(7)` for a list of
                      valid types.

                      If set to `null`, the type is assumed to be a disk or file.
                    '';
                  };

                  options.sources = mkOption {
                    type = types.listOf types.str;
                    example = [ "/dev/disk/by-label/wd-red-001" ];
                    description = ''
                      List of block devices to use for the virtual device. The
                      number of devices must match the type.

                      It's recommended to specify block devices by their UUID or
                      label to avoid overwriting to the wrong device.
                    '';
                  };
                }
              );
            };

            options.datasets = mkOption {
              default = { };
              description = "Defines ZFS datasets to manage within a pool";

              type = types.attrsOf (
                types.submodule (
                  { name, ... }:
                  {
                    options.name = mkOption {
                      type = types.str;
                      example = "tank/library";
                      default = name;
                      description = ''
                        Name of the ZFS dataset. The name must be unique within the
                        pool.
                      '';
                    };

                    options.properties = mkOption {
                      type = types.attrsOf types.str;
                      default = { };
                      description = ''
                        Mapping of ZFS dataset settings. See `zfsprops(7)` for a list
                        of available options.
                      '';
                    };
                  }
                )
              );
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      supportedFilesystems = [ "zfs" ];

      # Disable the prompt for encryption credentials on boot. It blocks ssh,
      # and RPi3 boot loaders aren't expressive enough to securely run an SSH
      # server in stage 1.
      zfs.requestEncryptionCredentials = false;
    };

    # Required by `zpool`. It uses the host ID as a unique marker ensuring
    # only one host mounts the disk at once.
    networking.hostId = lib.mkDefault hostId;

    # This is used by other units to defer start until FS mounts are ready.
    systemd.targets.${cfg.decryption.name} = {
      description = "ZFS Dataset Decryption";
      wants = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "zfs-attach" ''
        set -euo pipefail
        zpool import -a
        zfs load-key -a
        ${concatMapStringsSep "\n" (mountpoint: "mount ${mountpoint}") topoSortedMounts}
        systemctl start ${cfg.decryption.target}
      '')

      (pkgs.writeShellScriptBin "zfs-detach" ''
        set -euo pipefail
        systemctl stop ${cfg.decryption.target}
        ${concatMapStringsSep "\n" (mountpoint: "umount ${mountpoint}") (lib.reverseList topoSortedMounts)}
        zfs unload-key -a
      '')
    ];

    fileSystems = lib.mapAttrs (mountpoint: dataset: {
      device = dataset;
      fsType = "zfs";

      # Using `noauto` to prevent systemd from trying to mount the device at
      # boot, which fails because it is encrypted. The `zfs-attach` command
      # will mount the device later.
      options = [
        "zfsutil"
        "noauto"
      ];
    }) cfg.mounts;
  };
}
