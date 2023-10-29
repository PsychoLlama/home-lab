{ config, lib, pkgs, ... }:

with lib;

let
  mdns-interfaces = [ "vlan-iot" "wap" "vlan-guest" ];
  mdns-ports = [ 5353 ];

  xbox-ip-address = "10.0.2.250";
  xbox-live-ports = {
    tcp = [ 3074 ];
    udp = [ 3074 3075 88 500 3544 4500 ];
  };

in {
  imports = [ ../../modules/hardware/raspberry-pi-3.nix ];

  # Assign sensible names to the network interfaces.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ENV{ID_BUS}=="usb", ATTR{address}=="60:a4:b7:59:07:f2", NAME="wan"
    ACTION=="add", SUBSYSTEM=="net", ENV{ID_BUS}=="usb", ATTR{address}=="b0:a7:b9:2c:a9:b5", NAME="wap"
    ACTION=="add", SUBSYSTEM=="net", ENV{ID_BUS}=="usb", ATTR{address}=="b8:27:eb:60:f5:88", NAME="lan"
  '';

  # VLANs are sent by the WAP (a UniFi U6 Lite).
  networking.vlans = {
    vlan-iot = {
      id = 10;
      interface = "wap";
    };

    vlan-work = {
      id = 20;
      interface = "wap";
    };

    vlan-guest = {
      id = 30;
      interface = "wap";
    };
  };

  # Bridge mDNS between my IoT, Guest, and private LAN.
  services.avahi = {
    enable = true;
    reflector = true;
    openFirewall = false;
    nssmdns = true;
    interfaces = mdns-interfaces;
  };

  lab = {
    network = {
      ethernetAddress = "b8:27:eb:60:f5:88";
      ipAddress = "10.0.0.1";
    };

    router = {
      enable = true;
      debugging.enable = true;

      dns = {
        blocklist = "${pkgs.unstable.stevenblack-blocklist}/hosts";
        records = [ ];
      };

      network = {
        wan.interface = "wan"; # Dongle to WAN

        subnets = [
          {
            mask = "255.255.255.0";
            bits = 24;
            start = "10.0.0.0";
            broadcast = "10.0.0.255";

            lease = {
              start = "10.0.0.10";
              end = "10.0.0.200";
            };

            link = {
              interface = "lan"; # Dongle to ethernet switch
              address = "10.0.0.1";
            };
          }
          {
            mask = "255.255.255.0";
            bits = 24;
            start = "10.0.1.0";
            broadcast = "10.0.1.255";

            lease = {
              start = "10.0.1.10";
              end = "10.0.1.250";
            };

            link = {
              interface = "wap"; # Dongle to WAP (no VLAN)
              address = "10.0.1.1";
            };
          }
          {
            mask = "255.255.255.0";
            bits = 24;
            start = "10.0.2.0";
            broadcast = "10.0.2.255";

            lease = {
              start = "10.0.2.10";
              end = "10.0.2.250";
            };

            link = {
              interface = "vlan-iot"; # IoT/Untrusted VLAN
              address = "10.0.2.1";
            };
          }
          {
            mask = "255.255.255.0";
            bits = 24;
            start = "10.0.3.0";
            broadcast = "10.0.3.255";

            lease = {
              start = "10.0.3.10";
              end = "10.0.3.250";
            };

            link = {
              interface = "vlan-work"; # Work VLAN
              address = "10.0.3.1";
            };
          }
          {
            mask = "255.255.255.0";
            bits = 24;
            start = "10.0.4.0";
            broadcast = "10.0.4.255";

            lease = {
              start = "10.0.4.10";
              end = "10.0.4.250";
            };

            link = {
              interface = "vlan-guest"; # Guest VLAN
              address = "10.0.4.1";
            };
          }
        ];

        extraHosts = [
          {
            ethernetAddress = "b0:60:88:19:d2:55";
            ipAddress = "10.0.1.250";
            hostName = "ava";
          }
          {
            ethernetAddress = "20:16:42:06:2c:e3";
            ipAddress = xbox-ip-address;
            hostName = "xbox-console";
          }
        ];
      };
    };
  };

  # Although not technically part of the home lab, this is still my home
  # router and some networking requirements are bound to bleed over.
  #
  # This opens ports for multiplayer gaming on Xbox Live.
  networking = {
    nat.forwardPorts = forEach xbox-live-ports.tcp (port: {
      sourcePort = port;
      destination = "${xbox-ip-address}:${builtins.toString port}";
      proto = "tcp";
    }) ++ forEach xbox-live-ports.udp (port: {
      sourcePort = port;
      destination = "${xbox-ip-address}:${builtins.toString port}";
      proto = "udp";
    });

    firewall.interfaces.${config.lab.router.network.wan.interface} = {
      allowedUDPPorts = xbox-live-ports.udp;
      allowedTCPPorts = xbox-live-ports.tcp;
    };

    firewall.interfaces.vlan-iot.allowedUDPPorts = mdns-ports;
    firewall.interfaces.wap.allowedUDPPorts = mdns-ports;
  };

  system.stateVersion = "21.11";
}
