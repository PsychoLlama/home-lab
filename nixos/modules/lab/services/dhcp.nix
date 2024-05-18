{ config, lib, ... }:

with lib;

let
  cfg = config.lab.services.dhcp;

  # Enrich `cfg.networks` with data from `lab.networks`.
  networks = mapAttrs (
    _: network: network // { inherit (config.lab.networks.${network.id}) ipv4; }
  ) cfg.networks;
in
{
  options.lab.services.dhcp = {
    enable = mkEnableOption "Run a DHCP server";
    networks = mkOption {
      description = "DHCP server configuration per interface";
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options.interface = mkOption {
              type = types.str;
              description = "Network interface to bind";
            };

            options.id = mkOption {
              type = types.enum (attrNames config.lab.networks);
              description = "One of `lab.networks`";
              default = name;
            };
          }
        )
      );
    };

    nameservers = mkOption {
      type = types.listOf types.str;
      description = "DNS servers advertised to clients";
      default = [ ];
      example = [
        "1.1.1.1"
        "9.9.9.9"
      ];
    };

    reservations = mkOption {
      type = types.listOf (
        types.submodule {
          options.hw-address = mkOption {
            type = types.str;
            description = "MAC address of the host";
          };

          options.ip-address = mkOption {
            type = types.str;
            description = "IP address to assign to the host";
          };
        }
      );

      description = "Static DHCP reservations";
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    # Open DHCP ports on participating LAN interfaces.
    networking.firewall.interfaces = mapAttrs' (_: network: {
      name = network.interface;
      value.allowedUDPPorts = [ 67 ];
    }) networks;

    services.kea = {
      dhcp4 = {
        enable = true;
        settings = {
          valid-lifetime = 3600;
          renew-timer = 900;
          rebind-timer = 1800;

          lease-database = {
            type = "memfile";
            persist = true;
            name = "/var/lib/kea/dhcp4.leases";
          };

          interfaces-config = {
            dhcp-socket-type = "raw";
            interfaces = mapAttrsToList (_: network: network.interface) networks;
          };

          subnet4 = mapAttrsToList (_: network: {
            subnet = network.ipv4.subnet;
            pools = forEach network.ipv4.dhcp.pools (lease: {
              pool = "${lease.start} - ${lease.end}";
            });

            option-data =
              (optionals (cfg.nameservers != [ ]) [
                {
                  name = "domain-name-servers";
                  data = concatStringsSep ", " cfg.nameservers;
                }
              ])
              ++ [
                {
                  name = "routers";
                  data = network.ipv4.gateway;
                }
                {
                  name = "broadcast-address";
                  data = network.ipv4.broadcast;
                }
              ];
          }) networks;

          host-reservation-identifiers = [
            "hw-address"
            "client-id"
          ];

          reservations-global = true;
          reservations-in-subnet = true;
          reservations-out-of-pool = false;
          reservations = cfg.reservations;
        };
      };
    };
  };
}
