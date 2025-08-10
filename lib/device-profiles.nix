# Flake inputs given manually, not by the NixOS module system.
{ nixos-hardware, nixpkgs, ... }:

{
  raspberry-pi-3 = {
    imports = [ nixpkgs.nixosModules.notDetected ];
    deployment.tags = [ "rpi3" ];

    boot.loader = {
      # Grub is not compatible here. Prefer the Extlinux boot loader.
      grub.enable = false;

      # The RPI3 module for U-Boot works just as well, but Extlinux should be
      # lighter. I don't need anything fancy.
      generic-extlinux-compatible.enable = true;
    };

    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    # The Pi 3 has severely limited RAM.
    swapDevices = [
      {
        device = "/var/swapfile";
        size = 1024;
      }
    ];
  };

  raspberry-pi-4 = {
    imports = [
      nixos-hardware.nixosModules.raspberry-pi-4
      nixpkgs.nixosModules.notDetected
    ];

    deployment.tags = [ "rpi4" ];

    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    # Enable GPU acceleration.
    hardware.raspberry-pi."4".fkms-3d.enable = true;

    # Enable audio.
    services.pulseaudio.enable = true;

    # Necessary for building boot images and running NixOS tests.
    lab.host.builder.supportedFeatures = [
      "benchmark"
      "big-parallel"
      "kvm"
      "nixos-test"
    ];
  };

  cm3588 = {
    hardware.enableRedistributableFirmware = true;

    boot = {
      # Yoinked from `nixos-hardware`. It's the only meaningful export.
      kernelParams = [ "console=ttyS2,1500000n8" ];

      # Bootstrapped from `github:Mic92/nixos-aarch64-images#cm3588NAS`.
      loader = {
        grub.enable = false;
        generic-extlinux-compatible.enable = true;
      };
    };

    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };
}
