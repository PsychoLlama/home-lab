{
  imports = [ ../../hardware/raspberry-pi.nix ];

  services.service-mesh.enable = true;
  services.container-orchestration.enable = true;
}
