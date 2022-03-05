{ config, lib, pkgs, options, nodes, ... }:

# Turns the device into a simple router.
#
# Manages firewalls, routing, NAT, DHCP, and DNS.

with lib;

let
  inherit (import ../config) domain;
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

  defaultAliases = [{
    name = "dns";
    kind = "A";
    addresses = [ cfg.network.lan.address ];
  }];

  consulDnsAddresses =
    mapAttrsToList (_: node: node.config.lab.network.ipAddress + ":8600")
    (flip filterAttrs nodes (_: node: node.config.lab.consul.server.enable));

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

    ; Custom records
    ${concatMapStringsSep "\n" (record:
      concatMapStringsSep "\n"
      (address: "${record.name}  ${cfg.dns.ttl} IN ${record.kind} ${address}")
      record.addresses) (defaultAliases ++ cfg.dns.records)}
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

      records = mkOption {
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

          options.kind = mkOption {
            type = types.str;
            description = "DNS record kind";
            default = "CNAME";
          };
        });

        description = "Insert custom DNS records";
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
        (common) {
          bind lo ${cfg.network.lan.interface}

          log
          errors
          local
          nsid router
        }

        ${optionalString (length consulDnsAddresses > 0) ''
          lab.selfhosted.city {
            import common

            forward . ${toString consulDnsAddresses}
          }
        ''}

        . {
          import common
          cache

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
      authoritative = true;
      interfaces = [ lan.interface ];
      machines = allHosts;

      extraConfig = ''
        option subnet-mask ${lan.subnet.mask};
        option broadcast-address ${lan.subnet.broadcast};
        option routers ${lan.address};
        option domain-name-servers ${lan.address};

        subnet ${lan.subnet.base} netmask ${lan.subnet.mask} {
          range ${lan.subnet.range.start} ${lan.subnet.range.end};
        }
      '';
    };

    # SSH should not be accessible from the open internet.
    services.openssh.openFirewall = mkDefault false;

    # Enable strict reverse path filtering. This guards against some forms of
    # IP spoofing.
    boot.kernel.sysctl = {
      "net.ipv4.conf.default.rp_filter" = mkDefault 1;
      "net.ipv4.conf.${cfg.network.wan.interface}.rp_filter" = mkDefault 1;
      "net.ipv4.conf.${cfg.network.lan.interface}.rp_filter" = mkDefault 1;
    };

    assertions = forEach cfg.dns.records (service: {
      assertion = length service.addresses > 0;
      message = ''
        DNS record "${service.name}" needs at least one address.
      '';
    });
  };
}
