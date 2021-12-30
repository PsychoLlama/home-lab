{ config, lib, pkgs, options, ... }:

# Turns the device into a simple router.

let
  cfg = config.lab.router;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  domain = (import ../lib.nix).domain;
  hostsFile = unstable.writeText "coredns.hosts" ''
    # --- CUSTOM HOSTS ---
    ${cfg.network.lan.address}  router

    ${lib.concatMapStringsSep "\n" (machine:
      "${machine.ipAddress}  ${machine.hostName} ${machine.hostName}.${domain}")
    cfg.network.hosts}

    # --- BLOCKLIST ---
    ${builtins.readFile cfg.dns.blocklist}
  '';

in with lib; {
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
    };

    network = {
      hosts = options.services.dhcpd4.machines;

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

          hosts ${hostsFile} {
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
      machines = cfg.network.hosts;

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
  };
}
