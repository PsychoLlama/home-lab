{
  imports = [ ../../hardware/raspberry-pi-4.nix ];

  lab.secret-manager.enable = true;
  lab.service-mesh.enable = true;
  lab.nomad = {
    server.enable = true;
    enable = true;
  };

  system.stateVersion = "21.05";
}
