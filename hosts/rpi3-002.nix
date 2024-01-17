{ config, pkgs, lib, ... }:

let
  inherit (config.lab) domain;
  decryptionTargetName = "pool-decryption";
  decryptionTarget = "${decryptionTargetName}.target";

  zfs = dataset: {
    device = dataset;
    fsType = "zfs";
    options = [ "noauto" "zfsutil" ];
  };

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
  # -----------------------------------------
  # TODO: Migrate this to a file server role.
  # -----------------------------------------

  boot = {
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    supportedFilesystems = [ "zfs" ];

    # Disable the prompt for encryption credentials on boot. It blocks ssh,
    # and RPi3 boot loaders aren't expressive enough to securely run an SSH
    # server in stage 1.
    zfs.requestEncryptionCredentials = false;
  };

  systemd.targets.pool-decryption = {
    description = "ZFS Pool Decryption";
    wants = [ "local-fs.target" ];
    after = [ "local-fs.target" ];
  };

  environment.systemPackages = [
    (makeTaskRunner "nas-ctl" ''
      default:
        nas-ctl --list

      # Decrypt and mount all ZFS datasets.
      attach-storage:
        ${pkgs.zfs}/bin/zfs load-key -a

        mount /mnt/pool0
        mount /mnt/pool0/syncthing

        ${pkgs.systemd}/bin/systemctl start ${decryptionTarget}

      # Unmount ZFS datasets.
      detach-storage:
        ${pkgs.systemd}/bin/systemctl stop ${decryptionTarget}

        umount /mnt/pool0/syncthing
        umount /mnt/pool0

        ${pkgs.zfs}/bin/zfs unload-key -a
    '')
  ];

  systemd.services.syncthing = {
    requires = [ decryptionTarget ];
    after = [ decryptionTarget ];

    # Don't start automatically. Wait for pool decryption.
    wantedBy = lib.mkForce [ decryptionTarget ];
  };

  services = {
    syncthing = {
      enable = true;
      package = pkgs.unstable.syncthing;
      dataDir = "/mnt/pool0/syncthing";
      configDir = "/mnt/pool0/syncthing/.config";

      settings = {
        options.urAccepted = 3;
        gui.theme = "dark";

        folders."/mnt/pool0/syncthing/attic" = {
          id = "attic";
          devices = [ "laptop" "phone" ];
          label = "Attic";
        };

        devices = {
          laptop = {
            addresses = [ "tcp://ava.host.${domain}" ];
            id =
              "JPX6IWF-HZIA465-YNSYU4H-YTHKJL6-CO3KN66-EKMNT7O-7DBTGWI-V6ICAQN";
          };

          phone = {
            addresses = [ "dynamic" ];
            id =
              "S2U7KKV-SXJGOI3-6MSJWIT-U2JP32Y-HH7WZU5-ZDS6KAT-6CNYRAM-ZQTWZAQ";
          };
        };
      };
    };

    zfs = {
      autoSnapshot = {
        enable = true;
        flags = "-kp --utc";
      };

      autoScrub = {
        enable = true;
        pools = [ "pool0" ];
      };
    };
  };

  networking = {
    hostId = "e3cda066";

    firewall = {
      allowedTCPPorts = [ 22000 ]; # TCP Sync
      allowedUDPPorts = [ 22000 21027 ]; # QUIC + LAN Discovery
    };
  };

  # NOTE: ZFS mounts will fail unless the pool is decrypted. Make sure it does
  # not attempt to mount at boot.
  fileSystems = {
    "/mnt/pool0" = zfs "pool0";
    "/mnt/pool0/syncthing" = zfs "pool0/syncthing";
  };

  system.stateVersion = "23.05";
}
