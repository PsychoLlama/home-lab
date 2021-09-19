{
  imports = [ ../../hardware/raspberry-pi-4.nix ];

  services.service-mesh.enable = true;
  services.container-orchestration.enable = true;
}
