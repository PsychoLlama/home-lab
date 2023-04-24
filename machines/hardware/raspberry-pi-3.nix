{ pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;

  boot = {
    loader = {
      # Grub is not compatible here. Prefer the Extlinux boot loader.
      grub.enable = false;

      # The RPI3 module for U-Boot works just as well, but Extlinux should be
      # lighter. I don't need anything fancy.
      generic-extlinux-compatible.enable = true;
    };
  };

  nixpkgs.localSystem = {
    config = "aarch64-unknown-linux-gnu";
    system = "aarch64-linux";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  # The Pi 3 has severely limited RAM.
  swapDevices = [{
    device = "/var/swapfile";
    size = 1024;
  }];
}
