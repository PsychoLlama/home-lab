{
  imports = [ ../../hardware/raspberry-pi-3.nix ];

  lab.network = {
    ethernetAddress = "b8:27:eb:0b:a2:ff";
    ipAddress = "10.0.0.202";
  };

  system.stateVersion = "21.11";
}
