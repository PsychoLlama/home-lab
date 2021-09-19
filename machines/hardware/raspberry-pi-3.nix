{ pkgs, ... }:

{
  boot = {
    consoleLogLevel = 7;
    kernelPackages = pkgs.linuxPackages_latest;

    loader = {
      generic-extlinux-compatible.enable = true;
      grub.enable = false;
    };
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

  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
}
