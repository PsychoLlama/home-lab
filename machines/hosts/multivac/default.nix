{
  imports = [ ../../hardware/poweredge-r720.nix ];

  boot = {
    initrd.availableKernelModules = [ "megaraid_sas" "sr_mod" "ahci" ];
    loader.grub.device = "/dev/sda";
  };

  lab = {
    network = {
      ethernetAddress = "ec:f4:bb:d7:54:2b";
      ipAddress = "10.0.0.206";
    };

    consul.interface = "eno4";
    nomad.enable = true;
  };

  system.stateVersion = "21.05";
}
