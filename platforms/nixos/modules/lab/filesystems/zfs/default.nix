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

      ZFS requires some manual management (setup, decryption) so this module
      exposes `zfs-*` commands for administration tasks.

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

    # Required by `zpool`. It uses the host ID as a unique marker ensuring
    # only one host mounts the disk at once.
    networking.hostId = lib.mkDefault hostId;

    # This is used by other units to defer start until FS mounts are ready.
    systemd.targets.${cfg.decryption.name} = {
      description = "ZFS Dataset Decryption";
      wants = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
    };

    environment.systemPackages =
      let
        expectedStateFile = pkgs.writers.writeJSON "expected-state.json" zfsStateFile;
      in
      [
        (pkgs.unstable.writers.writeNuBin "zfs-attach"
          # nu
          ''
            # Decrypt and mount ZFS datasets.
            export def main [] {
              zfs load-key -a
              ${concatMapStringsSep "\n              " (mountpoint: "mount ${mountpoint}") topoSortedMounts}
              systemctl start ${cfg.decryption.target}
            }
          ''
        )

        (pkgs.unstable.writers.writeNuBin "zfs-detach"
          # nu
          ''
            # Unmount ZFS datasets.
            export def main [] {
              systemctl stop ${cfg.decryption.target}
              ${concatMapStringsSep "\n              " (mountpoint: "umount ${mountpoint}") (lib.reverseList topoSortedMounts)}
              zfs unload-key -a
            }
          ''
        )

        (pkgs.unstable.writers.writeNuBin "zfs-export-properties"
          # nu
          ''
            # Export known pool/dataset properties to a state file format.
            export def main [] {
              use ${nulib}/propctl.nu
              propctl export-system-state | to json
            }
          ''
        )

        (pkgs.unstable.writers.writeNuBin "zfs-apply-properties"
          # nu
          ''
            # Manage ZFS dataset properties and pool attributes.
            export def main [
              --state-file: string = "${expectedStateFile}"  # Path to JSON file with expected properties
              --yes (-y)  # Automatically confirm changes
            ] {
              $env.EXPECTED_STATE = $state_file
              if $yes { $env.AUTO_CONFIRM = "true" }
              use ${nulib}/propctl.nu
              propctl plan | propctl apply
            }
          ''
        )

        (pkgs.unstable.writers.writeNuBin "zfs-init"
          # nu
          ''
            # Create ZFS pools.
            export def main [] {
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
                (lib.concatStringsSep "\n              ")
              ]}

              # Create datasets.
              ${concatMapStringsSep "\n              " (
                pool:
                lib.pipe pool.datasets [
                  (lib.attrValues)
                  (map (dataset: "zfs create ${lib.escapeShellArg "${pool.name}/${dataset.name}"}"))
                  (lib.concatStringsSep "\n              ")
                ]
              ) (lib.attrValues cfg.pools)}

              # Apply pool/dataset properties.
              zfs-apply-properties --yes
            }
          ''
        )
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
