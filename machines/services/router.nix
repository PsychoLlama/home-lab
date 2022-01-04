{ config, lib, pkgs, options, nodes, ... }:

# Turns the device into a simple router.
#
# Manages firewalls, routing, NAT, DHCP, and DNS.

with lib;

let
  inherit (import ../lib.nix) domain;
  cfg = config.lab.router;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };

  # Each host optionally defines an ethernet+ip pairing. This extracts it from
  # every machine and converts it to the `services.dhcpd4.machines` format.
  labHosts = forEach (attrValues (filterAttrs (_: node:
    hasAttr "ethernetAddress" ((node.config.lab or { }).network or { })
    && node.config.lab.network.ethernetAddress != null) nodes)) (node: {
      inherit (node.config.lab.network) ethernetAddress ipAddress;
      hostName = node.config.networking.hostName;
    });

  allHosts = labHosts ++ cfg.network.extraHosts;

  # Provides easier access to the router and DNS servers.
  defaultServices = [
    {
      name = "dns";
      addresses = [ cfg.network.lan.address ];
    }
    {
      name = "router";
      addresses = [ cfg.network.lan.address ];
    }
  ];

  zoneFile = unstable.writeText "local.zone" ''
    $ORIGIN ${domain}.
    @       IN SOA dns trash (
            1         ; Version number
            60        ; Zone refresh interval
            30        ; Zone update retry timeout
            180       ; Zone TTL
            3600)     ; Negative response TTL

    ; Hosts
    ${concatMapStringsSep "\n" (machine:
      "${machine.hostName}.host  ${cfg.dns.ttl} IN A ${machine.ipAddress}")
    allHosts}

    ; Services
    ${concatMapStringsSep "\n" (service:
      concatMapStringsSep "\n"
      (address: "${service.name}  ${cfg.dns.ttl} IN A ${address}")
      service.addresses) (cfg.dns.services ++ defaultServices)}
  '';

in {
  options.lab.router = {
    enable = mkEnableOption "Act as a router";
    debugging.enable = mkEnableOption "Enable the debugging toolkit";

    dns = {
      upstream = {
        ipAddress = mkOption {
          type = types.str;
          default = "1.1.1.1";
          description = "IP address of the DNS server";
        };

        hostname = mkOption {
          type = types.str;
          default = "cloudflare-dns.com";
          description = "Server hostname (used for TLS)";
        };
      };

      # Facilitates DNS-level adblock.
      blocklist = mkOption {
        type = types.either types.str types.path;
        default = builtins.fetchurl {
          sha256 = "06bgjnl0x1apfpildg47jwjiz2fw1vapirfz45rs86qafcxmkbm2";
          url =
            "https://raw.githubusercontent.com/StevenBlack/hosts/3.9.30/hosts";
        };
      };

      services = mkOption {
        type = types.listOf (types.submodule {
          options.addresses = mkOption {
            type = types.listOf types.str;
            description = "IP addresses pointing to the service";
          };

          options.name = mkOption {
            type = types.str;
            description = ''
              Any BIND zone record identifier, usually a subdomain name.
              Use <literal>@</literal> for apex records.

              Note: Only domains within the lab's zone are recognized.
            '';
          };
        });

        description = "Load balance a list of IPs assigned to a service record";
        default = [ ];
      };

      ttl = mkOption {
        type = types.str;
        description = "TTL for custom DNS records";
        default = "60";
      };
    };

    network = {
      extraHosts = options.services.dhcpd4.machines;

      wan = {
        interface = mkOption {
          type = types.str;
          description = "WAN interface";
        };
      };

      lan = {
        interface = mkOption {
          type = types.str;
          description = "LAN interface";
        };

        address = mkOption {
          type = types.str;
          default = "10.0.0.1";
          description = "Static LAN IP of the router";
        };

        # Some of this is redundant, but the complexity of parsing IPs is too
        # tedious to be worthwhile.
        subnet = {
          mask = mkOption {
            type = types.str;
            default = "255.255.255.0";
            description = "Subnet mask for the LAN";
          };

          bits = mkOption {
            type = types.int;
            default = 24;
            description = ''
              The corresponding number of bits in the subnet mask.
              It must be kept in sync with `subnet.mask`.
            '';
          };

          base = mkOption {
            type = types.str;
            default = "10.0.0.0";
            description = "The first IP address in the subnet";
          };

          broadcast = mkOption {
            type = types.str;
            default = "10.0.0.255";
            description = "Subnet broadcast address";
          };

          range = {
            start = mkOption {
              type = types.str;
              default = "10.0.0.10";
              description = "Starting range for DHCP";
            };

            end = mkOption {
              type = types.str;
              default = "10.0.0.200";
              description = "Ending range for DHCP";
            };
          };
        };
      };
    };
  };

  # DHCP can sync ethernet addresses with IPs for more consistent topologies.
  # Each host that wants a reservation should set this field.
  options.lab.network = {
    ethernetAddress = mkOption {
      type = types.nullOr types.str;
      description = "MAC address of the machine.";
      default = null;
    };

    ipAddress = mkOption {
      type = types.nullOr types.str;
      description = "IP address of the machine.";
      default = null;
    };
  };

  config = mkIf cfg.enable {
    networking = {
      useDHCP = false;
      interfaces.${cfg.network.wan.interface}.useDHCP = mkDefault true;
      interfaces.${cfg.network.lan.interface} = {
        useDHCP = false;

        ipv4.addresses = [{
          address = cfg.network.lan.address;
          prefixLength = cfg.network.lan.subnet.bits;
        }];
      };

      nat = {
        enable = true;
        externalInterface = cfg.network.wan.interface;
        internalInterfaces = [ cfg.network.lan.interface ];
        internalIPs = [
          "${cfg.network.lan.address}/${
            builtins.toString cfg.network.lan.subnet.bits
          }"
        ];
      };

      firewall.interfaces.${cfg.network.lan.interface} = {
        allowedTCPPorts = [ 22 ];
        allowedUDPPorts = [ 53 ];
      };
    };

    environment.systemPackages = mkIf cfg.debugging.enable [
      unstable.bottom # System load observer
      unstable.dogdns # DNS testing
      unstable.tcpdump # Inspect traffic (used with Wireshark)
      unstable.conntrack-tools # Inspect active connection states
    ];

    services.coredns = {
      enable = true;
      package = unstable.coredns;
      config = ''
        .:53 {
          bind lo ${cfg.network.lan.interface}

          log
          errors
          cache
          local
          nsid router
          loadbalance round_robin

          file ${zoneFile} ${domain} {
            reload 0
          }

          hosts ${cfg.dns.blocklist} {
            fallthrough
            reload 0
            ttl 60
          }

          forward . tls://${cfg.dns.upstream.ipAddress} {
            tls_servername ${cfg.dns.upstream.hostname}
            health_check 1h
          }
        }
      '';
    };

    services.dhcpd4 = with cfg.network; {
      enable = true;
      interfaces = [ lan.interface ];
      machines = allHosts;

      extraConfig = ''
        option subnet-mask ${lan.subnet.mask};
        option broadcast-address ${lan.subnet.broadcast};
        option routers ${lan.address};
        option domain-name-servers ${lan.address};
        authoritative;

        subnet ${lan.subnet.base} netmask ${lan.subnet.mask} {
          range ${lan.subnet.range.start} ${lan.subnet.range.end};
        }
      '';
    };

    # SSH should not be accessible from the open internet.
    services.openssh.openFirewall = mkDefault false;

    assertions = forEach cfg.dns.services (service: {
      assertion = length service.addresses > 0;
      message = ''
        DNS service "${service.name}" needs at least one IP address.
      '';
    });
  };
}
