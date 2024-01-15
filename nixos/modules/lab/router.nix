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

  allHosts = labHosts ++ cfg.dhcp.leases;

  defaultAliases = [{
    name = "dns";
    kind = "A";
    addresses = mapAttrsToList (_: network: network.ipv4.gateway) cfg.networks;
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

    dhcp.leases = options.services.dhcpd4.machines;

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

      zoneFile = mkOption {
        type = types.path;
        default = zoneFile;
        description = ''
          Path to a BIND zone file. Setting this option will override
          the generated config.
        '';
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

    wan.interface = mkOption {
      type = types.str;
      description = "WAN interface";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      useDHCP = false;

      # Don't use the ISP nameservers, use the locally configured DNS.
      nameservers = [ "127.0.0.1" ];

      interfaces = mkMerge [
        {
          # Get a public IP from the WAN link, presumably an ISP.
          ${cfg.wan.interface}.useDHCP = mkDefault true;
        }

        # Statically assign the gateway IP to all managed LAN interfaces.
        (mapAttrs' (_: network: {
          name = network.interface;
          value = {
            useDHCP = false;
            ipv4.addresses = [{
              address = network.ipv4.gateway;
              prefixLength = network.ipv4.prefixLength;
            }];
          };
        }) cfg.networks)
      ];

      nat = {
        enable = true;
        externalInterface = cfg.wan.interface;
        internalInterfaces =
          mapAttrsToList (_: network: network.interface) cfg.networks;

        internalIPs = mapAttrsToList (_: network:
          "${network.ipv4.gateway}/${toString network.ipv4.prefixLength}")
          cfg.networks;
      };

      # Expose SSH and DNS to all LAN interfaces.
      firewall.interfaces = mapAttrs' (_: network: {
        name = network.interface;
        value = {
          allowedTCPPorts = [ 22 ];
          allowedUDPPorts = [ 53 ];
        };
      }) cfg.networks;
    };

    environment.systemPackages = [
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
            (mapAttrsToList (_: network: network.interface) cfg.networks)
          }

          log
          errors
          local
          nsid router
        }

        . {
          import common
          cache

          file ${cfg.dns.zoneFile} ${domain} {
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

    services.dhcpd4 = {
      enable = true;
      authoritative = true;
      interfaces = mapAttrsToList (_: network: network.interface) cfg.networks;
      machines = allHosts;

      extraConfig = ''
        ${lib.pipe cfg.networks [
          # TODO: Use network.ipv4.nameservers and support multiple ranges.
          (mapAttrsToList (_: network: ''
            subnet ${network.ipv4.network} netmask ${network.ipv4.netmask} {
              option subnet-mask ${network.ipv4.netmask};
              option broadcast-address ${network.ipv4.broadcast};
              option routers ${network.ipv4.gateway};
              option domain-name-servers ${network.ipv4.gateway};
              range ${(head network.ipv4.dhcp.ranges).start} ${
                (head network.ipv4.dhcp.ranges).end
              };
            }
          ''))

          (concatStringsSep "\n")
        ]}
      '';
    };

    # SSH should not be accessible from the open internet.
    services.openssh.openFirewall = mkDefault false;

    # Enable strict reverse path filtering. This guards against some forms of
    # IP spoofing.
    boot.kernel.sysctl = mkMerge [
      {
        # Enable for the WAN interface.
        "net.ipv4.conf.default.rp_filter" = mkDefault 1;
        "net.ipv4.conf.${cfg.wan.interface}.rp_filter" = mkDefault 1;
      }

      # Enable for all LAN interfaces.
      (mapAttrs' (_: network: {
        name = "net.ipv4.conf.${network.interface}.rp_filter";
        value = mkDefault 1;
      }) cfg.networks)
    ];

    assertions = forEach cfg.dns.records (service: {
      assertion = length service.addresses > 0;
      message = ''
        DNS record "${service.name}" needs at least one address.
      '';
    });
  };
}
