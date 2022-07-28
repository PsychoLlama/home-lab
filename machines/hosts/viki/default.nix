{ config, lib, nodes, inputs, ... }:

with lib;

let
  mdns-interfaces = [ "vlan0" "eth1" "vlan2" ];
  mdns-ports = [ 5353 ];

  xbox-ip-address = "10.0.2.250";
  xbox-live-ports = {
    tcp = [ 3074 ];
    udp = [ 3074 3075 88 500 3544 4500 ];
  };

in {
  imports = [ ../../hardware/raspberry-pi-3.nix ];

  # VLANs are sent by the WAP (a UniFi U6 Lite).
  networking.vlans = {
    vlan0 = {
      id = 10;
      interface = "eth1";
    };

    vlan1 = {
      id = 20;
      interface = "eth1";
    };

    vlan2 = {
      id = 30;
      interface = "eth1";
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
        blocklist = "${inputs.dns-blocklist}/hosts";
        records = [{
          name = "@";
          addresses = [ "private-ingress.service" ];
        }];
      };

      network = {
        wan.interface = "eth2"; # Dongle to WAN

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
              interface = "eth0"; # Dongle to ethernet switch
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
              interface = "eth1"; # Dongle to WAP (no VLAN)
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
              interface = "vlan0"; # IoT/Untrusted VLAN
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
              interface = "vlan1"; # Work VLAN
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
              interface = "vlan2"; # Guest VLAN
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
            ethernetAddress = "98:5f:d3:14:0b:30";
            ipAddress = xbox-ip-address;
            hostName = "xbox-one";
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

    firewall.interfaces.vlan0.allowedUDPPorts = mdns-ports;
    firewall.interfaces.eth1.allowedUDPPorts = mdns-ports;
  };

  system.stateVersion = "21.11";
}
