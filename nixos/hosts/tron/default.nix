{
  imports = [../common/raspberry-pi.nix];

  # Enable audio.
  hardware.pulseaudio.enable = true;
}
