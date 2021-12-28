{
  imports = [ ../../hardware/raspberry-pi-3.nix ];

  lab.router = {
    enable = true;
    debugging.enable = true;
    network.lan.interface = "eth0"; # Native hardware
    network.wan.interface = "eth1"; # Dongle
  };

  system.stateVersion = "21.11";
}
