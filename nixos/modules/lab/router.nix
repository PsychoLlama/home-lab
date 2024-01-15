{ config, lib, pkgs, options, nodes, ... }:

# Turns the device into a simple router.
#
# Manages firewalls, routing, NAT, DHCP, and DNS.

with lib;

let
  inherit (config.lab) domain networks;
  cfg = config.lab.router;

  # Each host defines an ethernet+ip pairing. This extracts it from every
  # machine and converts it to the `services.dhcpd4.machines` format.
  labHosts = lib.mapAttrsToList (_: node:
    let
      inherit (node.config) networking;
      inherit (node.config.lab) host;

    in {
      hostName = networking.hostName;
      ethernetAddress = host.ethernet;
      ipAddress = host.ip4;
    }) nodes;

  allHosts = labHosts ++ cfg.network.extraHosts;

  defaultAliases = [{
    name = "dns";
    kind = "A";
    addresses = forEach cfg.network.subnets (subnet: subnet.link.address);
  }];

  zoneFile = pkgs.unstable.writeText "local.zone" ''
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
        default = pkgs.writeText "empty" "# no hosts";
        description = ''
          Domains to replace with a sinkhole address. Works with popular
          blocklists. The file contents should be structured as `/etc/hosts`.
        '';
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

    networks = mkOption {
      description = "Map of networks to create from `lab.networks`";
      default = { };
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        options = {
          name = mkOption {
            description = "One of `lab.networks`";
            type = types.enum (attrNames networks);
            default = name;
          };

          interface = mkOption {
            description = "Name of the network interface to use";
            type = types.str;
          };

          # Aliases into `lab.networks` for convenience.
          ipv4 = mkOption {
            type = types.anything;
            readOnly = true;
            default = networks.${config.name}.ipv4;
          };
        };
      }));
    };

    network = {
      extraHosts = options.services.dhcpd4.machines;

      wan.interface = mkOption {
        type = types.str;
        description = "WAN interface";
      };

      subnets = mkOption {
        description = "IP ranges assigned by DHCP";
        default = [ ];

        # Some of this is redundant, but the complexity of parsing IPs is too
        # tedious to be worthwhile.
        type = types.listOf (types.submodule {
          options.mask = mkOption {
            type = types.str;
            description = "Subnet mask in string form (e.g. '255.0.0.0')";
          };

          options.bits = mkOption {
            type = types.int;
            description = ''
              The corresponding number of bits in the subnet mask.
              It must be kept in sync with `subnet.mask`.
            '';
          };

          options.start = mkOption {
            type = types.str;
            description = "The first IP address in the subnet";
          };

          options.broadcast = mkOption {
            type = types.str;
            description = "Subnet broadcast address";
          };

          options.lease = {
            start = mkOption {
              type = types.str;
              description = "Starting range for DHCP";
            };

            end = mkOption {
              type = types.str;
              description = "Ending range for DHCP";
            };
          };

          options.link = {
            interface = mkOption {
              type = types.str;
              description = "Name of a LAN interface";
            };

            address = mkOption {
              type = types.str;
              description = "Static IP for the interface";
            };
          };
        });
      };
    };
  };

  config = mkIf cfg.enable {
    networking = {
      useDHCP = false;

      # Assign static IPs to the appropriate interfaces and configure DHCP for
      # the WAN upstream.
      interfaces = recursiveUpdate (listToAttrs (forEach cfg.network.subnets
        (subnet:
          nameValuePair subnet.link.interface {
            useDHCP = false;
            ipv4.addresses = [{
              address = subnet.link.address;
              prefixLength = subnet.bits;
            }];
          }))) { ${cfg.network.wan.interface}.useDHCP = mkDefault true; };

      nat = {
        enable = true;
        externalInterface = cfg.network.wan.interface;
        internalInterfaces = forEach cfg.network.subnets (x: x.link.interface);
        internalIPs = forEach cfg.network.subnets
          (subnet: "${subnet.link.address}/${toString subnet.bits}");
      };

      # Expose SSH and DNS to all LAN subnets.
      firewall.interfaces = listToAttrs (forEach cfg.network.subnets (subnet:
        nameValuePair subnet.link.interface {
          allowedTCPPorts = [ 22 ];
          allowedUDPPorts = [ 53 ];
        }));
    };

    environment.systemPackages = mkIf cfg.debugging.enable [
      pkgs.unstable.bottom # System load observer
      pkgs.unstable.dogdns # DNS testing
      pkgs.unstable.tcpdump # Inspect traffic (used with Wireshark)
      pkgs.unstable.conntrack-tools # Inspect active connection states
    ];

    services.coredns = {
      enable = true;
      package = pkgs.unstable.coredns;
      config = ''
        (common) {
          bind lo ${
            toString
            (forEach cfg.network.subnets (subnet: subnet.link.interface))
          }

          log
          errors
          local
          nsid router
        }

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
      interfaces = forEach cfg.network.subnets (subnet: subnet.link.interface);
      machines = allHosts;

      extraConfig = ''
        ${concatMapStringsSep "\n" (subnet: ''
          subnet ${subnet.start} netmask ${subnet.mask} {
            option subnet-mask ${subnet.mask};
            option broadcast-address ${subnet.broadcast};
            option routers ${subnet.link.address};
            option domain-name-servers ${subnet.link.address};
            range ${subnet.lease.start} ${subnet.lease.end};
          }
        '') cfg.network.subnets}
      '';
    };

    # SSH should not be accessible from the open internet.
    services.openssh.openFirewall = mkDefault false;

    # Enable strict reverse path filtering. This guards against some forms of
    # IP spoofing.
    boot.kernel.sysctl = {
      "net.ipv4.conf.default.rp_filter" = mkDefault 1;
      "net.ipv4.conf.${cfg.network.wan.interface}.rp_filter" = mkDefault 1;
    } // (listToAttrs (forEach cfg.network.subnets (subnet:
      nameValuePair "net.ipv4.conf.${subnet.link.interface}.rp_filter"
      (mkDefault 1))));

    assertions = forEach cfg.dns.records (service: {
      assertion = length service.addresses > 0;
      message = ''
        DNS record "${service.name}" needs at least one address.
      '';
    });
  };
}
