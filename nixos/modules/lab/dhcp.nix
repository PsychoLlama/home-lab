{ config, lib, options, ... }:

with lib;

let cfg = config.lab.dhcp;

in {
  options.lab.dhcp = {
    enable = mkEnableOption "Run a DHCP server";
    networks = options.lab.router.networks;
    reservations = mkOption {
      type = types.listOf (types.submodule {
        options.hw-address = mkOption {
          type = types.str;
          description = "MAC address of the host";
        };

        options.ip-address = mkOption {
          type = types.str;
          description = "IP address to assign to the host";
        };
      });

      description = "Static DHCP reservations";
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    # Open DHCP ports on participating LAN interfaces.
    networking.firewall.interfaces = mapAttrs' (_: network: {
      name = network.interface;
      value.allowedUDPPorts = [ 67 ];
    }) cfg.networks;

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
            interfaces =
              mapAttrsToList (_: network: network.interface) cfg.networks;
          };

          subnet4 = mapAttrsToList (_: network: {
            subnet = network.ipv4.subnet;
            pools = forEach network.ipv4.dhcp.ranges
              (lease: { pool = "${lease.start} - ${lease.end}"; });

            option-data = [
              {
                name = "domain-name-servers";
                data = concatStringsSep ", " network.ipv4.nameservers;
              }
              {
                name = "routers";
                data = network.ipv4.gateway;
              }
            ];
          }) cfg.networks;

          host-reservation-identifiers = [ "hw-address" "client-id" ];
          reservations-global = true;
          reservations-in-subnet = true;
          reservations-out-of-pool = false;
          reservations = cfg.reservations;
        };
      };
    };
  };
}
