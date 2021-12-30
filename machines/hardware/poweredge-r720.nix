{ modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    kernelModules = [ "kvm-intel" ];
    initrd.availableKernelModules =
      [ "ehci_pci" "usbhid" "usb_storage" "sd_mod" ];

    loader.grub = {
      enable = true;
      version = 2;
    };
  };

  networking = {
    useDHCP = false;
    interfaces = {
      eno1.useDHCP = true;
      eno2.useDHCP = true;
      eno3.useDHCP = true;
      eno4.useDHCP = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
  };

  swapDevices = [{ device = "/dev/disk/by-label/swap"; }];
}
