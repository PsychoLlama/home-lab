{ config, lib, ... }:

let
  inherit (lib) types mkOption;

  cfg = config.lab.services.dhcp;

  # Enrich `cfg.networks` with data from `lab.networks`.
  networks = lib.mapAttrs (
    _: network: network // { inherit (config.lab.networks.${network.id}) ipv4; }
  ) cfg.networks;
in
{
  options.lab.services.dhcp = {
    enable = lib.mkEnableOption "Run a DHCP server";
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
              type = types.enum (lib.attrNames config.lab.networks);
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
          options.type = mkOption {
            type = types.enum [
              "hw-address"
              "client-id"
            ];

            description = "Reservation type";
            default = "client-id";
          };

          options.id = mkOption {
            type = types.str;
            description = "DHCP reservation identifier";
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

    # On the fence whether `dhcp.lib` is genius or an anti-pattern.
    lib.toClientId = mkOption {
      type = types.functionTo types.str;
      readOnly = true;
      description = ''
        Convert an IPv4 address to a DHCP client identifier. Useful when you
        want to "hard-code" the IP but keep the router, DNS, and other fields
        dynamic.

        Outputs a hex string for compatibility with Kea.
      '';

      default =
        ip4:
        lib.pipe ip4 [
          # ["127", "0", "0", "1"]
          (lib.splitString ".")

          # [127, 0, 0, 1]
          (lib.map (str: lib.strings.toInt str))

          # ["7F", "0", "0", "1"]
          (lib.map (number: lib.trivial.toHexString number))

          # ["7F", "00", "00", "01"]
          (lib.map (hex: lib.strings.fixedWidthString 2 "0" hex))

          # "7F:00:00:01"
          (lib.concatStringsSep ":")

          # "FE:01:7F:00:00:01"
          (id: "FE:01:${id}")
        ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Open DHCP ports on participating LAN interfaces.
    networking.firewall.interfaces = lib.mapAttrs' (_: network: {
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
            interfaces = lib.mapAttrsToList (_: network: network.interface) networks;
          };

          subnet4 = lib.imap (index: network: {
            id = index;
            subnet = network.ipv4.subnet;
            pools = lib.forEach network.ipv4.dhcp.pools (lease: {
              pool = "${lease.start} - ${lease.end}";
            });

            option-data =
              (lib.optionals (cfg.nameservers != [ ]) [
                {
                  name = "domain-name-servers";
                  data = lib.concatStringsSep ", " cfg.nameservers;
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
          }) (lib.attrValues networks);

          host-reservation-identifiers = [
            "hw-address"
            "client-id"
          ];

          reservations-global = true;
          reservations-in-subnet = true;
          reservations-out-of-pool = false;
          reservations = map (reservation: {
            inherit (reservation) ip-address;
            ${reservation.type} = reservation.id;
          }) cfg.reservations;
        };
      };
    };
  };
}
