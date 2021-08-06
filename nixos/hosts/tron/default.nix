{
  imports = [../common/raspberry-pi.nix];

  services.nomad.enable = true;
  services.vault.enable = true;
}
