{ config, pkgs, lib, ... }:

let
  inherit (config.lab.settings) domain;
  decryptionTargetName = "pool-decryption";
  decryptionTarget = "${decryptionTargetName}.target";

in {
  imports = [ ../../modules/hardware/raspberry-pi-3.nix ];

  lab.network = {
    ethernetAddress = "b8:27:eb:0b:a2:ff";
    ipAddress = "10.0.0.202";
  };

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
    (pkgs.writers.writeBashBin "mount-zfs-datasets" ''
      set -euo pipefail

      echo "Importing pool"
      ${pkgs.zfs}/bin/zpool import pool0
      ${pkgs.zfs}/bin/zpool list

      echo "Loading decryption keys"
      ${pkgs.zfs}/bin/zfs load-key -a

      echo "Mounting datasets"

      mount -t zfs -o zfsutil pool0 /mnt/pool0
      mount -t zfs -o zfsutil pool0/syncthing /mnt/pool0/syncthing

      echo "Mounted successfully."
      mount -t zfs

      echo "Enabling dependent systemd services"
      ${pkgs.systemd}/bin/systemctl start ${decryptionTarget}
    '')

    (pkgs.writers.writeBashBin "unmount-zfs-datasets" ''
      set -euo pipefail

      echo "Stopping dependent systemd services"
      ${pkgs.systemd}/bin/systemctl stop ${decryptionTarget}

      echo "Unmounting ZFS datasets"
      umount /mnt/pool0/syncthing
      umount /mnt/pool0

      echo "Releasing decryption keys"
      ${pkgs.zfs}/bin/zfs unload-key -a

      echo "Exporting ZFS pools"
      ${pkgs.zfs}/bin/zpool export -a
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

      extraOptions = {
        options.urAccepted = 3;
        gui.theme = "dark";
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

  system.stateVersion = "21.11";
}
