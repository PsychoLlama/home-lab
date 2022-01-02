{
  imports = [ ../../hardware/raspberry-pi-4.nix ];

  lab.service-mesh.enable = true;
  lab.container-orchestration.enable = true;

  system.stateVersion = "21.05";
}
