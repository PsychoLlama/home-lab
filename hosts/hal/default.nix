{ config, unstable, ... }:

let inherit (config.lab.settings) domain;

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
  };

  fileSystems = let
    dataset = name: {
      device = name;
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  in {
    "/mnt/pool0" = dataset "pool0";
    "/mnt/pool0/syncthing" = dataset "pool0/syncthing";
  };

  services = {
    syncthing = {
      enable = true;
      package = unstable.syncthing;
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
