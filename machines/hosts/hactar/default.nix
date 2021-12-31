{ pkgs, ... }:

{
  imports = [ ../../hardware/poweredge-r720.nix ];

  boot = {
    initrd.availableKernelModules = [ "mpt3sas" ];
    loader.grub.device = "/dev/sda";
  };

  lab.file-server = {
    enable = true;
    hostId = "a26860d3";
    pools = [ "pool0" ];
  };

  # None of my hard drives support trimming.
  services.zfs.trim.enable = false;

  fileSystems = {
    "/mnt/pool0" = {
      device = "pool0";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

    "/mnt/pool0/attic" = {
      device = "pool0/attic";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
  };

  system.stateVersion = "21.11";
}
