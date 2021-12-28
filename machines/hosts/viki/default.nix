{
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
          ipAddress = "10.0.0.201";
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
      ];
    };
  };

  system.stateVersion = "21.11";
}
