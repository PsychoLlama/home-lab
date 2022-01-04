{
  imports = [ ../../hardware/raspberry-pi-4.nix ];

  lab = {
    network = {
      ethernetAddress = "dc:a6:32:e1:42:81";
      ipAddress = "10.0.0.203";
    };

    secret-manager.enable = true;

    service-mesh = {
      server.enable = true;
      enable = true;
    };

    nomad = {
      server.enable = true;
      enable = true;
    };
  };

  system.stateVersion = "21.05";
}
