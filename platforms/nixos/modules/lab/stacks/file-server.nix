{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (config.lab) domain;
  inherit (config.lab.filesystems.zfs) decryption pools;
  cfg = config.lab.stacks.file-server;
in

{
  options.lab.stacks.file-server = {
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
              "nvme0n1"
              "nvme1n1"
              "nvme2n1"
            ];
          }
        ];

        # NOTE: Some properties must be set at creation time.
        # This script doesn't support it.
        properties = {
          xattr = "on";
          acltype = "posix";
          atime = "off";
          keylocation = "prompt";
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
            label = "Attic";
            devices = [
              "laptop"
              "phone"
            ];
          };

          devices = {
            laptop = {
              addresses = [ "tcp://ava.host.${domain}" ];
              id = "JPX6IWF-HZIA465-YNSYU4H-YTHKJL6-CO3KN66-EKMNT7O-7DBTGWI-V6ICAQN";
            };

            phone = {
              addresses = [ "dynamic" ];
              id = "7B5KM6T-7NXKMY5-KM7TIQJ-WFX2OBO-OHMZOPA-HAXTV5B-5RNKXFM-OEF5AAL";
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
