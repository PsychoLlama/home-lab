{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:

with lib;

let
  inherit (config.lab.services.gateway.networks) home iot guest;
  inherit (config.lab.services.gateway) wan;
  cfg = config.lab.profiles.router;

  # Reserve IP addresses for all hosts.
  hostReservations = mapAttrsToList (_: node: {
    hw-address = node.config.lab.host.ethernet;
    ip-address = node.config.lab.host.ip4;
  }) nodes;

  # Generate DNS records for every host.
  hostRecords = mapAttrsToList (_: node: {
    name = "${node.config.networking.hostName}.host";
    value = node.config.lab.host.ip4;
    type = "A";
  }) nodes;

  laptop = {
    ip4 = "10.0.1.250";
    hostName = "ava";
  };

  xbox = {
    ip4 = "10.0.2.250";
    ports = {
      tcp = [ 3074 ];
      udp = [
        3074
        3075
        88
        500
        3544
        4500
      ];
    };
  };

  networks = {
    datacenter.interface = "lan"; # Dongle to ethernet switch
    home.interface = "wap"; # Dongle to WAP (no VLAN)
    iot.interface = "vlan-iot";
    work.interface = "vlan-work";
    guest.interface = "vlan-guest";
  };
in
{
  options.lab.profiles.router = {
    enable = mkEnableOption ''
      Turn this device into a router.

      The network interface names MUST match the ones configured in
      `router.networks`. Configure them with udev before enabling this
      profile.
    '';
  };

  config = mkIf cfg.enable {
    deployment.tags = [ "router" ];

    environment.systemPackages = [
      pkgs.unstable.bottom # System load observer
      pkgs.unstable.conntrack-tools # Inspect active connection states
      pkgs.unstable.doggo # DNS testing
      pkgs.unstable.tcpdump # Inspect traffic (used with Wireshark)
    ];

    # VLANs are sent by the WAP (a UniFi U6 Lite).
    networking.vlans = {
      vlan-iot = {
        id = 10;
        interface = home.interface;
      };

      vlan-work = {
        id = 20;
        interface = home.interface;
      };

      vlan-guest = {
        id = 30;
        interface = home.interface;
      };
    };

    # Bridge mDNS between my IoT, Guest, and Home LAN.
    services.avahi = {
      enable = true;
      reflector = true;
      openFirewall = false;
      nssmdns4 = true;
      allowInterfaces = [
        iot.interface
        home.interface
        guest.interface
      ];
    };

    networking = {
      # Don't use DNS servers advertised by the ISP.
      inherit (config.lab.services.dhcp) nameservers;
    };

    lab.services = {
      gateway = {
        enable = true;
        wan.interface = "wan"; # Dongle to WAN
        networks = networks;
      };

      dhcp = {
        enable = true;
        networks = networks;

        # NOTE: DNS IP address may be in a different subnet. This still
        # depends on the gateway to forward traffic.
        nameservers = pipe nodes [
          (filterAttrs (_: node: node.config.lab.services.dns.enable))
          (mapAttrsToList (_: node: node.config.lab.host.ip4))
        ];

        reservations = hostReservations ++ [
          {
            hw-address = "b0:60:88:19:d2:55";
            ip-address = laptop.ip4;
          }
          {
            hw-address = "20:16:42:06:2c:e3";
            ip-address = xbox.ip4;
          }
        ];
      };

      dns = {
        enable = true;
        interfaces = mapAttrsToList (_: net: net.interface) networks;
        server.id = config.networking.fqdn;
        hosts.file = "${pkgs.unstable.stevenblack-blocklist}/hosts";

        zone = {
          name = config.lab.domain;
          records = hostRecords ++ [
            {
              name = "${laptop.hostName}.host";
              value = laptop.ip4;
              type = "A";
            }
          ];
        };

        forward = [
          {
            zone = ".";
            tls = {
              ip = "1.1.1.1";
              servername = "cloudflare-dns.com";
            };
          }
        ];
      };
    };

    # Although not technically part of the home lab, this is still my home
    # router and some networking requirements are bound to bleed over.
    networking = {
      # Open ports for multiplayer gaming on Xbox Live.
      nat.forwardPorts = flatten (
        mapAttrsToList (
          proto: ports:
          forEach ports (port: {
            inherit proto;
            sourcePort = port;
            destination = "${xbox.ip4}:${toString port}";
          })
        ) xbox.ports
      );

      firewall.interfaces =
        let
          mdns = [ 5353 ];
        in
        {
          # Allow IoT devices to be discoverable from the Home LAN.
          ${iot.interface}.allowedUDPPorts = mdns;
          ${home.interface}.allowedUDPPorts = mdns;

          ${wan.interface} = {
            allowedUDPPorts = xbox.ports.udp;
            allowedTCPPorts = xbox.ports.tcp;
          };
        };
    };
  };
}
