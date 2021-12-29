{ lib, ... }:

let
  xbox-live-ports = {
    tcp = [ 3074 ];
    udp = [ 3074 3075 88 500 3544 4500 ];
  };

in with lib; {
  imports = [ ../../hardware/raspberry-pi-3.nix ];

  lab.router = {
    enable = true;
    debugging.enable = true;

    network = {
      lan.interface = "eth0"; # Native hardware
      wan.interface = "eth1"; # Dongle

      hosts = [
        {
          ethernetAddress = "b8:27:eb:60:f5:88";
          ipAddress = "10.0.0.1";
          hostName = "viki";
        }
        {
          ethernetAddress = "b8:27:eb:0b:a2:ff";
          ipAddress = "10.0.0.202";
          hostName = "hal";
        }
        {
          ethernetAddress = "dc:a6:32:e1:42:81";
          ipAddress = "10.0.0.203";
          hostName = "clu";
        }
        {
          ethernetAddress = "dc:a6:32:77:bb:82";
          ipAddress = "10.0.0.204";
          hostName = "tron";
        }
        {
          ethernetAddress = "68:1c:a2:13:55:6f";
          ipAddress = "10.0.0.205";
          hostName = "corvus";
        }
        {
          ethernetAddress = "ec:f4:bb:d7:54:2b";
          ipAddress = "10.0.0.206";
          hostName = "multivac";
        }
        {
          ethernetAddress = "ec:f4:bb:d6:4b:4b";
          ipAddress = "10.0.0.207";
          hostName = "file-server";
        }
        {
          ethernetAddress = "98:5f:d3:14:0b:30";
          ipAddress = "10.0.0.250";
          hostName = "xbox-one";
        }
      ];
    };
  };

  # Although not technically part of the home lab, this is still my home
  # router and some networking requirements are bound to bleed over.
  #
  # This opens ports for multiplayer gaming on Xbox Live.
  networking.nat.forwardPorts = forEach xbox-live-ports.tcp (port: {
    sourcePort = port;
    destination = "10.0.0.250:${builtins.toString port}";
    proto = "tcp";
  }) ++ forEach xbox-live-ports.udp (port: {
    sourcePort = port;
    destination = "10.0.0.250:${builtins.toString port}";
    proto = "udp";
  });

  networking.firewall.allowedTCPPorts = xbox-live-ports.tcp;
  networking.firewall.allowedUDPPorts = xbox-live-ports.udp;

  system.stateVersion = "21.11";
}
