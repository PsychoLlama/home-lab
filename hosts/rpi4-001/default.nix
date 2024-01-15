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
  # Assign sensible names to the network interfaces. Anything with vlans needs
  # a hardware-related filter to avoid conflicts with virtual devices.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ENV{ID_BUS}=="usb", ATTR{address}=="b0:a7:b9:2c:a9:b5", NAME="wap"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="60:a4:b7:59:07:f2", NAME="wan"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="dc:a6:32:e1:42:81", NAME="lan"
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
    router = {
      enable = true;
      debugging.enable = true;

      dns = {
        blocklist = "${pkgs.unstable.stevenblack-blocklist}/hosts";
        records = [ ];
      };

      networks = {
        datacenter.interface = "lan"; # Dongle to ethernet switch
        home.interface = "wap"; # Dongle to WAP (no VLAN)
        iot.interface = "vlan-iot";
        work.interface = "vlan-work";
        guest.interface = "vlan-guest";
      };

      network = {
        wan.interface = "wan"; # Dongle to WAN
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

  system.stateVersion = "21.05";
}
