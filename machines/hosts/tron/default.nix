{
  imports = [ ../../hardware/raspberry-pi-4.nix ];

  lab = {
    network = {
      ethernetAddress = "dc:a6:32:77:bb:82";
      ipAddress = "10.0.0.204";
    };

    vault-server.enable = true;

    consul = {
      server.enable = true;
      enable = true;
    };

    nomad = {
      server.enable = true;
      enable = true;
    };

    acme.enable = true;
  };

  system.stateVersion = "21.05";
}
