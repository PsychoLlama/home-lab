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

  makeTaskRunner = command: justfile:
    pkgs.stdenvNoCC.mkDerivation {
      name = command;
      buildInputs = [ pkgs.makeWrapper ];
      phases = [ "installPhase" ];
      installPhase = ''
        makeWrapper ${pkgs.just}/bin/just $out/bin/${command} \
          --prefix PATH : ${placeholder "out"}/bin \
          --add-flags --justfile \
          --add-flags ${pkgs.writeText "justfile" justfile}
      '';
    };

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

    environment.systemPackages = [
      (makeTaskRunner "file-storage" ''
        default:
          file-storage --list

        # Decrypt and mount ZFS datasets.
        attach:
          zfs load-key -a

          ${
            concatMapStringsSep "\n  " (mountpoint: "mount ${mountpoint}")
            topoSortedMounts
          }

          systemctl start ${cfg.decryption.target}

        # Unmount ZFS datasets.
        detach:
          systemctl stop ${cfg.decryption.target}

          ${
            concatMapStringsSep "\n  " (mountpoint: "umount ${mountpoint}")
            (reverseList topoSortedMounts)
          }

          zfs unload-key -a
      '')
    ];

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
