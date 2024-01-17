{ config, lib, pkgs, options, ... }:

with lib;

let
  inherit (config.lab) domain networks;
  cfg = config.lab.router;

in {
  options.lab.router = {
    enable = mkEnableOption "Turn the device into a simple router";

    dhcp.reservations = options.lab.dhcp.reservations;

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
        default = pkgs.unstable.writeText "local.zone" ''
          $ORIGIN ${domain}.
          @       IN SOA dns trash (
                  1         ; Version number
                  60        ; Zone refresh interval
                  30        ; Zone update retry timeout
                  180       ; Zone TTL
                  3600)     ; Negative response TTL

          ; Custom records
          ${concatMapStringsSep "\n" (record:
            "${record.name}  ${record.ttl} IN ${record.type} ${record.value}")
          cfg.dns.records}
        '';

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
          options.value = mkOption {
            type = types.str;
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

          options.type = mkOption {
            type = types.str;
            description = "The type of DNS record to create";
            default = "CNAME";
          };

          options.ttl = mkOption {
            type = types.str;
            description = "Length of time in seconds to cache the record";
            default = "60";
          };
        });

        description = "Insert custom DNS records";
        default = [ ];
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

    lab.dhcp = {
      enable = true;
      networks = cfg.networks;
      reservations = cfg.dhcp.reservations;
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
  };
}
