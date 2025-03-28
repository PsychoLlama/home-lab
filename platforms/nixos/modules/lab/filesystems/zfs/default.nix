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

  nulib = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (f: f.hasExt "nu") ./.;
  };

  # Expected property/settings for zpools and datasets. Managed by
  # `./propctl.nu`.
  zfsStateFile = {
    pools = lib.mapAttrs (_: pool: {
      ignored_properties = pool.unmanaged.settings;
      properties = pool.settings;
    }) cfg.pools;

    datasets = lib.pipe cfg.pools [
      (lib.attrValues)

      (map (pool: [
        # Declare pool properties
        {
          ${pool.name} = {
            ignored_properties = pool.unmanaged.properties;
            inherit (pool) properties;
          };
        }

        # Declare dataset properties
        (lib.mapAttrs' (_: dataset: {
          name = "${pool.name}/${dataset.name}";
          value = {
            ignored_properties = dataset.unmanaged.properties;
            inherit (dataset) properties;
          };
        }) pool.datasets)
      ]))

      (lib.flatten)
      (lib.mergeAttrsList)
    ];
  };
in
{
  options.lab.filesystems.zfs = {
    enable = lib.mkEnableOption ''
      Mount and manage encrypted ZFS pools. This option changes the kernel and
      boot process. Reboot the machine after changing this option.

      ZFS requires some manual management (setup, decryption) so this module
      exposes a `system fs` command for administration tasks.

      Be aware that any services depending on ZFS datasets will fail to start
      until the datasets are decrypted and mounted. Defer services with
      `zfs.decryption.target`.
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

    # Since storage admin is potentially dangerous and occasionally requires
    # manual intervention (e.g. encryption keys), managing pools, datasets,
    # and properties in code is just as much an exercise in documentation as
    # execution. Things may fail. That's okay. At least you'll know how the
    # system should look.
    pools = mkOption {
      default = { };
      description = ''
        Mapping of pool names to ZFS pool configurations.

        This option doesn't do anything by default. It adds administration
        commands that generate the pool, but for safety it only takes effect
        when run manually.
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

            options.settings = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = ''
                Mapping of ZFS pool settings. See `zpoolprops(7)` for a list of
                available options.
              '';

              example = {
                autoexpand = "on";
                autotrim = "off";
              };
            };

            options.properties = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = ''
                Mapping of ZFS filesystem props to apply. See `zfsprops(7)` for
                a list of available options.
              '';
            };

            options.unmanaged = {
              settings = mkOption {
                type = types.listOf types.str;
                description = "Unmanaged zpool settings to ignore.";
                default = [ ];
              };

              properties = mkOption {
                type = types.listOf types.str;
                description = "Unmanaged dataset properties to ignore.";
                default = [ "nixos:shutdown-time" ];
              };
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

                    options.unmanaged.properties = mkOption {
                      type = types.listOf types.str;
                      description = "Unmanaged dataset properties to ignore.";
                      default = [ ];
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

    # This is used by other units to defer start until FS mounts are ready.
    systemd.targets.${cfg.decryption.name} = {
      description = "ZFS Dataset Decryption";
      wants = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
    };

    lab.system.fs = {
      about = "ZFS management tools";
      subcommands = {
        attach = {
          about = "Decrypt and mount ZFS datasets";
          run = pkgs.writers.writeBash "attach-storage" ''
            set -euxo pipefail

            zfs load-key -a

            ${concatMapStringsSep "\n  " (mountpoint: "mount ${mountpoint}") topoSortedMounts}

            systemctl start ${cfg.decryption.target}
          '';
        };

        detach = {
          about = "Unmount ZFS datasets";
          run = pkgs.writers.writeBash "detach-storage" ''
            set -euxo pipefail

            systemctl stop ${cfg.decryption.target}

            ${concatMapStringsSep "\n  " (mountpoint: "umount ${mountpoint}") (
              lib.reverseList topoSortedMounts
            )}

            zfs unload-key -a
          '';
        };

        export-properties = {
          about = "Export known pool/dataset properties to a state file format";
          run = pkgs.unstable.writers.writeNu "export-zfs-properties.nu" ''
            use ${nulib}/propctl.nu
            propctl export-system-state | to json
          '';
        };

        apply-properties = {
          about = "Manage ZFS dataset properties and pool attributes";

          run = pkgs.unstable.writers.writeNu "manage-zfs-properties.nu" ''
            use ${nulib}/propctl.nu
            propctl plan | propctl apply
          '';

          args = [
            {
              id = "EXPECTED_STATE";
              value_name = "FILE_PATH";
              about = "Path to a JSON file containing the expected properties";
              default_value = pkgs.writers.writeJSON "expected-state.json" zfsStateFile;
            }
            {
              id = "AUTO_CONFIRM";
              about = "Automatically confirm changes";
              short = "y";
              long = "yes";
            }
          ];
        };

        init = {
          about = "Create ZFS pools";
          run = pkgs.writers.writeBash "init-storage" ''
            set -euxo pipefail

            # Create ZFS pools.
            ${lib.pipe cfg.pools [
              (lib.attrValues)
              (map (
                pool:
                "zpool create ${lib.escapeShellArg pool.name} ${
                  concatMapStringsSep " " (
                    vdev: lib.concatStringsSep " " ((if vdev.type != null then [ vdev.type ] else [ ]) ++ vdev.sources)
                  ) pool.vdevs
                }"
              ))

              (lib.concatStringsSep "\n  ")
            ]}

            # Create datasets.
            ${concatMapStringsSep "\n  " (
              pool:
              lib.pipe pool.datasets [
                (lib.attrValues)
                (map (dataset: "zfs create ${lib.escapeShellArg "${pool.name}/${dataset.name}"}"))
                (lib.concatStringsSep "\n  ")
              ]
            ) (lib.attrValues cfg.pools)}

            # Apply pool/dataset properties.
            system fs apply-properties --yes=true
          '';
        };
      };
    };

    fileSystems = lib.mapAttrs (mountpoint: dataset: {
      device = dataset;
      fsType = "zfs";

      # Using `noauto` to prevent systemd from trying to mount the device at
      # boot, which fails because it is encrypted. The `system fs` command
      # will mount the device later.
      options = [
        "zfsutil"
        "noauto"
      ];
    }) cfg.mounts;
  };
}
