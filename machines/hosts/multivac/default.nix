{
  imports = [ ../../hardware/poweredge-r720.nix ];

  boot = {
    initrd.availableKernelModules = [ "megaraid_sas" "sr_mod" "ahci" ];
    loader.grub.device = "/dev/sda";
  };

  system.stateVersion = "21.05";
}
