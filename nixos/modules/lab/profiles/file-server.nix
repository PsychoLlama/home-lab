{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (config.lab) domain;
  inherit (config.lab.filesystems.zfs) decryption pools;
  cfg = config.lab.profiles.file-server;
in
{
  options.lab.profiles.file-server = {
    enable = lib.mkEnableOption "Run a file server";
  };

  config = lib.mkIf cfg.enable {
    deployment.tags = [ "file-server" ];

    lab.filesystems.zfs = {
      enable = true;
      mounts = {
        "/mnt/pool0" = "pool0";
        "/mnt/pool0/syncthing" = "pool0/syncthing";
      };

      pools.pool0 = {
        vdevs = [
          {
            type = "raidz1";
            sources = [
              "sda"
              "sdb"
              "sdc"
            ];
          }
        ];

        properties = {
          xattr = "sa";
          acltype = "posixacl";
          atime = "off";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          compression = "on";
          mountpoint = "none";
        };

        datasets.syncthing.properties."com.sun:auto-snapshot" = "true";
      };
    };

    systemd.services.syncthing = {
      requires = [ decryption.target ];
      after = [ decryption.target ];

      # Don't start automatically. Wait for pool decryption.
      wantedBy = lib.mkForce [ decryption.target ];
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
            devices = [
              "laptop"
              "phone"
            ];
            label = "Attic";
          };

          devices = {
            laptop = {
              addresses = [ "tcp://ava.host.${domain}" ];
              id = "JPX6IWF-HZIA465-YNSYU4H-YTHKJL6-CO3KN66-EKMNT7O-7DBTGWI-V6ICAQN";
            };

            phone = {
              addresses = [ "dynamic" ];
              id = "S2U7KKV-SXJGOI3-6MSJWIT-U2JP32Y-HH7WZU5-ZDS6KAT-6CNYRAM-ZQTWZAQ";
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
          pools = lib.attrNames pools;
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 22000 ]; # TCP Sync
      allowedUDPPorts = [
        22000
        21027
      ]; # QUIC + LAN Discovery
    };
  };
}
