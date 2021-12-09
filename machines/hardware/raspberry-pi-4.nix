{
  imports = [
    "${
      fetchTarball
      "https://github.com/NixOS/nixos-hardware/archive/4c9f07277bd4bc29a051ff2a0ca58c6403e3881a.tar.gz"
    }/raspberry-pi/4"
  ];

  nixpkgs.localSystem = {
    config = "aarch64-unknown-linux-gnu";
    system = "aarch64-linux";
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # Enable GPU acceleration.
  hardware.raspberry-pi."4".fkms-3d.enable = true;

  # Enable audio.
  hardware.pulseaudio.enable = true;
}
