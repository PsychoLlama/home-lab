{ pkgs, ... }:

let unstable = import ../../unstable-pkgs.nix { system = pkgs.system; };

in {
  imports = [ ../../hardware/poweredge-r720.nix ];

  boot = {
    initrd.availableKernelModules = [ "mpt3sas" ];
    loader.grub.device = "/dev/sda";
  };

  lab = {
    network = {
      ethernetAddress = "ec:f4:bb:d6:4b:4b";
      ipAddress = "10.0.0.207";
    };

    file-server = {
      enable = true;
      hostId = "a26860d3";
      pools = [ "pool0" ];
      mounts = {
        "/mnt/pool0" = "pool0";
        "/mnt/pool0/syncthing" = "pool0/syncthing";
      };

      services.syncthing = {
        enable = true;
        package = unstable.syncthing;
        dataDir = "/mnt/pool0/syncthing";

        folders."/syncthing/attic" = {
          id = "attic";
          devices = [ "laptop" "phone" ];
          label = "Attic";
        };

        devices = {
          laptop = {
            addresses = [ "dynamic" ];
            id =
              "JPX6IWF-HZIA465-YNSYU4H-YTHKJL6-CO3KN66-EKMNT7O-7DBTGWI-V6ICAQN";
          };

          phone = {
            addresses = [ "dynamic" ];
            id =
              "YTUVZSZ-V4TOBKD-SCKD4B6-AOW5TMT-PGCLJO6-7MLGZII-FOYC7JO-LGP62AX";
          };
        };

        extraOptions = {
          options.urAccepted = 3;
          gui.theme = "dark";
        };
      };
    };
  };

  # None of my hard drives support trimming.
  services.zfs.trim.enable = false;

  system.stateVersion = "21.11";
}
