{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:

let
  inherit (config.lab.services.gateway.networks)
    home
    iot
    guest
    datacenter
    ;

  inherit (config.lab.services.gateway) wan;
  inherit (config.lab.services) discovery;
  cfg = config.lab.stacks.router;
  json = pkgs.formats.json { };

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
  options.lab.stacks.router = {
    enable = lib.mkEnableOption ''
      Turn this device into a router.

      The network interface names MUST match the ones configured in
      `router.networks`. Configure them with udev before enabling this
      stack.
    '';
  };

  config = lib.mkIf cfg.enable {
    deployment.tags = [ "router" ];
    lab.services.vpn.client.tags = [ "router" ];

    environment.systemPackages = [
      pkgs.unstable.bottom # System load observer
      pkgs.unstable.conntrack-tools # Inspect active connection states
      pkgs.unstable.doggo # DNS testing
      pkgs.unstable.tcpdump # Inspect traffic (used with Wireshark)
      config.services.etcd.package # For probing dynamic DNS records
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

      # Powers host and service discovery.
      discovery.server = {
        enable = true;
        dns.zone = "${config.lab.datacenter}.${config.lab.domain}";

        static-values = [
          {
            key = "${discovery.server.dns.prefix.host.key}/${config.networking.hostName}";
            value = json.generate "host-record.json" {
              host = config.lab.host.ip4;
              type = "A";
              # use default TTL
            };
          }
        ];

        allowInterfaces = [
          home.interface
          datacenter.interface
        ];
      };

      dhcp = {
        enable = true;
        networks = networks;

        discovery = {
          enable = true;
          dns.prefix = discovery.server.dns.prefix.host.key;
        };

        # NOTE: DNS IP address may be in a different subnet. This still
        # depends on the gateway to forward traffic.
        nameservers = lib.pipe nodes [
          (lib.filterAttrs (_: node: node.config.lab.services.dns.enable))
          (lib.mapAttrsToList (_: node: node.config.lab.host.ip4))
        ];

        reservations = [
          {
            type = "hw-address";
            id = "C4:CB:76:8A:C3:D7";
            ip-address = xbox.ip4;
          }
        ];
      };

      dns = {
        enable = true;
        interfaces = lib.mapAttrsToList (_: net: net.interface) networks;
        server.id = config.networking.fqdn;
        hosts.file = "${pkgs.unstable.stevenblack-blocklist}/hosts";
        zone.name = "host.${config.lab.domain}";
        prometheus.enable = true;

        discovery = {
          enable = true;
          dns.prefix = "/${discovery.server.dns.prefix.name}";

          zones = [
            "host.${discovery.server.dns.zone}"
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
      nat.forwardPorts = lib.flatten (
        lib.mapAttrsToList (
          proto: ports:
          lib.forEach ports (port: {
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
