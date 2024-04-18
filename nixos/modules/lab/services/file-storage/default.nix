{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.lab.services.file-storage;

  # Example: "/mnt/tank" must be mounted before "/mnt/tank/library".
  # FS dependency order can be inferred by string length.
  topoSortedMounts = pipe cfg.mounts [
    attrsToList
    (sortOn (mount: stringLength mount.name))
    (map (mount: mount.name))
  ];

in {
  options.lab.services.file-storage = {
    enable = mkEnableOption ''
      Mount and manage encrypted ZFS pools. This option changes the kernel and
      boot process. Reboot the machine after changing this option.

      ZFS requires some manual management (setup, decryption) so this module
      exposes a `file-storage` command for administration tasks.

      Be aware that any services depending on ZFS datasets will fail to start
      until the datasets are decrypted and mounted. Defer services with
      `file-storage.services.decryption.target`.
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
      example = { "/mnt/tank" = "tank"; };
      description = "Mapping of mount points to ZFS datasets";
    };

    # TODO: Move pool management out of Nix. This domain is not well suited to
    # bash scripts and the risk of damage is too high.
    #
    # Since storage admin is potentially dangerous and occasionally requires
    # manual intervention (e.g. encryption keys) this module serves more as
    # executable documentation and a way to quickly recreate or port a setup.
    pools = mkOption {
      default = { };
      description = ''
        Mapping of pool names to ZFS pool configurations.

        This option doesn't do anything by default. It adds administration
        commands that generate the pool, but for safety it only takes effect
        when run manually.
      '';

      type = types.attrsOf (types.submodule ({ name, ... }: {
        options.name = mkOption {
          type = types.str;
          example = "tank";
          description = "Name of the ZFS pool";
          default = name;
        };

        options.settings = mkOption {
          type = types.attrs;
          default = { };
          description = ''
            Mapping of ZFS pool settings. See `zpoolprops(7)` for a list of
            available options.
          '';
        };

        options.properties = mkOption {
          type = types.attrs;
          default = { };
          description = ''
            Mapping of ZFS filesystem props to apply. See `zfsprops(7)` for
            a list of available options.
          '';
        };

        options.vdevs = mkOption {
          default = [ ];
          type = types.listOf (types.submodule {
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
          });
        };

        options.datasets = mkOption {
          default = { };
          description = "Defines ZFS datasets to manage within a pool";

          type = types.attrsOf (types.submodule ({ name, ... }: {
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
              type = types.attrs;
              default = { };
              description = ''
                Mapping of ZFS dataset settings. See `zfsprops(7)` for a list
                of available options.
              '';
            };
          }));
        };
      }));
    };
  };

  config = mkIf cfg.enable {
    boot = {
      kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
      supportedFilesystems = [ "zfs" ];

      # Disable the prompt for encryption credentials on boot. It blocks ssh,
      # and RPi3 boot loaders aren't expressive enough to securely run an SSH
      # server in stage 1.
      zfs.requestEncryptionCredentials = false;
    };

    # This is used by other units to defer start until FS mounts are ready.
    systemd.targets.${cfg.decryption.name} = {
      description = "ZFS Dataset Decryption";
      wants = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
    };

    lab.system.file-storage = {
      about = "ZFS management tools";
      subcommands = {
        attach = {
          about = "Decrypt and mount ZFS datasets";
          run = pkgs.writers.writeBash "attach-storage" ''
            set -euxo pipefail

            zfs load-key -a

            ${concatMapStringsSep "\n  " (mountpoint: "mount ${mountpoint}")
            topoSortedMounts}

            systemctl start ${cfg.decryption.target}
          '';
        };

        detach = {
          about = "Unmount ZFS datasets";
          run = pkgs.writers.writeBash "detach-storage" ''
            set -euxo pipefail

            systemctl stop ${cfg.decryption.target}

            ${concatMapStringsSep "\n  " (mountpoint: "umount ${mountpoint}")
            (reverseList topoSortedMounts)}

            zfs unload-key -a
          '';
        };

        apply-properties = {
          about = "Synchronize ZFS properties";
          run = pkgs.writers.writePython3 "sync-zfs-props" { } ./zfs_attrs.py;
          args = [{
            id = "EXPECTED_STATE";
            value_name = "FILE_PATH";
            about = "Path to a JSON file containing the expected properties";
            # TODO: Assign default value to computed state file.
          }];
        };

        init = {
          about = "Create ZFS pools";
          run = pkgs.writers.writeBash "init-storage" ''
            set -euxo pipefail

            # Create ZFS pools.
            ${pipe cfg.pools [
              (attrValues)
              (map (pool:
                "zpool create ${escapeShellArg pool.name} ${
                  concatMapStringsSep " " (vdev:
                    concatStringsSep " "
                    ((if vdev.type != null then [ vdev.type ] else [ ])
                      ++ vdev.sources)) pool.vdevs
                }"))

              (concatStringsSep "\n  ")
            ]}

            # Apply pool settings.
            ${pipe cfg.pools [
              (attrValues)
              (filter (pool: pool.settings != { }))
              (map (pool:
                pipe pool.settings [
                  (attrsToList)
                  (map (setting:
                    "zpool set ${escapeShellArg setting.name}=${
                      escapeShellArg (toString setting.value)
                    } ${escapeShellArg pool.name}"))
                  (concatStringsSep "\n  ")
                ]))

              (concatStringsSep "\n  ")
            ]}

            # Apply filesystem properties.
            ${pipe cfg.pools [
              (attrValues)
              (filter (pool: pool.properties != { }))
              (map (pool:
                pipe pool.properties [
                  (attrsToList)
                  (map (prop:
                    "zfs set ${escapeShellArg prop.name}=${
                      escapeShellArg (toString prop.value)
                    } ${escapeShellArg pool.name}"))
                  (concatStringsSep "\n  ")
                ]))

              (concatStringsSep "\n  ")
            ]}

            # Create datasets.
            ${concatMapStringsSep "\n  " (pool:
              pipe pool.datasets [
                (attrValues)
                (map (dataset:
                  "zfs create ${
                    escapeShellArg "${pool.name}/${dataset.name}"
                  }"))
                (concatStringsSep "\n  ")
              ]) (attrValues cfg.pools)}

            # Apply dataset properties.
            ${concatMapStringsSep "\n  " (pool:
              pipe pool.datasets [
                (attrValues)
                (filter (dataset: dataset.properties != { }))
                (map (dataset:
                  pipe dataset.properties [
                    (attrsToList)
                    (map (prop:
                      "zfs set ${escapeShellArg prop.name}=${
                        escapeShellArg (toString prop.value)
                      } ${escapeShellArg "${pool.name}/${dataset.name}"}"))
                    (concatStringsSep "\n  ")
                  ]))
                (concatStringsSep "\n  ")
              ]) (attrValues cfg.pools)}
          '';
        };
      };
    };

    fileSystems = mapAttrs (mountpoint: dataset: {
      device = dataset;
      fsType = "zfs";

      # Using `noauto` to prevent systemd from trying to mount the device at
      # boot, which fails because it is encrypted. The `file-storage` command
      # will mount the device later.
      options = [ "zfsutil" "noauto" ];
    }) cfg.mounts;
  };
}
