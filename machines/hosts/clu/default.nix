{
  imports = [ ../../hardware/raspberry-pi-4.nix ];

  lab.network = {
    ethernetAddress = "dc:a6:32:e1:42:81";
    ipAddress = "10.0.0.203";
  };

  system.stateVersion = "21.05";
}
