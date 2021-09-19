{
  imports = [
    "${
      fetchTarball
      "https://github.com/NixOS/nixos-hardware/archive/09ed30ff3bb67f5efe9c77e0d79aca01793526ca.tar.gz"
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
