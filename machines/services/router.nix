{ config, lib, pkgs, ... }:

# Turns the device into a simple router.

let
  cfg = config.lab.router;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };

in with lib; {
  options.lab.router = {
    enable = mkEnableOption "Act as a router";
    debugging.enable = mkEnableOption "Enable the debugging toolkit";

    dns = {
      servers = mkOption {
        type = types.listOf types.str;
        default = [ "1.1.1.1" ];
        description = "Upstream DNS servers";
      };
    };

    network = {
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
              default = "10.0.0.254";
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
    };

    environment.systemPackages = mkIf cfg.debugging.enable [
      unstable.bottom # System load observer
      unstable.dogdns # DNS testing
      unstable.tcpdump # Inspect traffic (used with Wireshark)
      unstable.conntrack-tools # Inspect active connection states
    ];

    services.dhcpd4 = with cfg.network; {
      enable = true;
      interfaces = [ lan.interface ];

      extraConfig = ''
        option subnet-mask ${lan.subnet.mask};
        option broadcast-address ${lan.subnet.broadcast};
        option routers ${lan.address};
        option domain-name-servers ${concatStringsSep ", " cfg.dns.servers};
        authoritative;

        subnet ${lan.subnet.base} netmask ${lan.subnet.mask} {
          range ${lan.subnet.range.start} ${lan.subnet.range.end};
        }
      '';
    };
  };
}
