{
  imports = [ ../../hardware/raspberry-pi-4.nix ];

  lab = {
    network = {
      ethernetAddress = "dc:a6:32:77:bb:82";
      ipAddress = "10.0.0.204";
    };

    nomad.enable = true;
  };

  system.stateVersion = "21.05";
}
