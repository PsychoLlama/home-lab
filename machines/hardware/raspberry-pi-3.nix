{ pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;

  boot = {
    loader = {
      generic-extlinux-compatible.enable = true;
      grub.enable = false;

      raspberryPi = {
        enable = true;
        version = 3;
        uboot.enable = true;
      };
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
