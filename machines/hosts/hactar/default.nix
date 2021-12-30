{ pkgs, ... }:

{
  imports = [ ../../hardware/poweredge-r720.nix ];
  boot = {
    initrd.availableKernelModules = [ "mpt3sas" ];
    loader.grub.device = "/dev/sda";
  };

  system.stateVersion = "21.11";
}
