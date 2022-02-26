{ pkgs, ... }:

let
  unstable = import ../../unstable-pkgs.nix { system = pkgs.system; };
  inherit (import ../../config) domain;

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
        "/mnt/pool0/borg" = "pool0/borg";
      };

      services.borg = {
        enable = true;
        basePath = "/mnt/pool0/borg";
        backups = [ "ava" ];
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
            addresses = [ "tcp://ava.host.${domain}" ];
            id =
              "JPX6IWF-HZIA465-YNSYU4H-YTHKJL6-CO3KN66-EKMNT7O-7DBTGWI-V6ICAQN";
          };

          phone = {
            addresses = [ "dynamic" ];
            id =
              "G6MC3RD-GQZ6MUT-MCAOAWP-5JQZTPE-6IEACQV-PWXRW23-KIPCLL2-UQVKLAU";
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
