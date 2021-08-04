{ config, pkgs, lib, ... }:

{
  imports = [
    "${fetchTarball "https://github.com/NixOS/nixos-hardware/archive/09ed30ff3bb67f5efe9c77e0d79aca01793526ca.tar.gz"}/raspberry-pi/4"
  ];

  nixpkgs.crossSystem = {
    system = "aarch64-linux";
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
  };

  # Enable audio.
  hardware.pulseaudio.enable = true;

  # Enable GPU acceleration.
  hardware.raspberry-pi."4".fkms-3d.enable = true;
}
