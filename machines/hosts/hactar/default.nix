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
    mounts = {
      "/mnt/pool0" = "pool0";
      "/mnt/pool0/attic" = "pool0/attic";
    };
  };

  # None of my hard drives support trimming.
  services.zfs.trim.enable = false;

  system.stateVersion = "21.11";
}
