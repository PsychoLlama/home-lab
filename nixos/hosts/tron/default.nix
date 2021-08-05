{
  imports = [../common/raspberry-pi.nix];

  # Enable audio.
  hardware.pulseaudio.enable = true;

  services.nomad.enable = true;
  services.consul.enable = true;
}
