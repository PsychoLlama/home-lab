{
  imports = [ ../../hardware/raspberry-pi-4.nix ];

  lab = {
    network = {
      ethernetAddress = "e4:5f:01:0e:c7:66";
      ipAddress = "10.0.0.208";
    };
  };

  system.stateVersion = "21.11";
}
