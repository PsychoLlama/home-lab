{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types mkOption;

  cfg = config.lab.services.dhcp;
  kea = pkgs.kea; # Not configurable outside nixpkgs.
  etcd = config.services.etcd.package;

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

    discovery = {
      enable = lib.mkEnableOption "Sync DHCP leases with etcd";

      dns.prefix = lib.mkOption {
        type = types.str;
        description = ''
          Etcd key prefix where DNS records are stored.
          Uses reverse scheme, e.g. `/dns/com/example/subdomain`.
        '';
      };
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

    lib.toSubnetId = mkOption {
      type = types.functionTo types.int;
      readOnly = true;
      description = ''
        Convert a network ID to a subnet ID by hashing the network name.
      '';

      default =
        networkName:
        lib.pipe networkName [
          (builtins.hashString "md5")

          # Trim to avoid exceeding the max integer size of 2^32.
          (lib.substring 0 7)

          # Hashes are hex encoded.
          lib.fromHexString

          # Subnet IDs must never be zero.
          (builtins.add 1)
        ];
    };

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
          (lib.map lib.strings.toInt)

          # ["7F", "0", "0", "1"]
          (lib.map lib.trivial.toHexString)

          # ["7F", "00", "00", "01"]
          (lib.map (lib.strings.fixedWidthString 2 "0"))

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

          # TODO: This should live somewhere else. It's still rather
          # experimental.
          hooks-libraries = lib.mkIf cfg.discovery.enable [
            {
              library = "${kea}/lib/kea/hooks/libdhcp_run_script.so";
              parameters = {
                sync = false; # Non-blocking script
                name = pkgs.unstable.writers.writeNu "sync-records-to-etcd.nu" ''
                  use std/log

                  # etcd freaks out if the path isn't set. It seems to be
                  # unset by default.
                  $env.PATH = []

                  # Synchronize DHCP leases to etcd when they change.
                  def main [event: string] {
                    if $event != "leases4_committed" {
                      return
                    }

                    let count_added = $env.LEASES4_SIZE | into int
                    let count_removed = $env.DELETED_LEASES4_SIZE | into int
                    log info $"Leases changed added=($count_added) removed=($count_removed)"

                    let added = seq 1 $count_added | enumerate | each {|item|
                      {
                        hostname: ($env | get $"LEASES4_AT($item.index)_HOSTNAME")
                        ip: ($env | get $"LEASES4_AT($item.index)_ADDRESS")
                      }
                    }

                    let removed = seq 1 $count_removed | enumerate | each {|item|
                      {
                        hostname: ($env | get $"DELETED_LEASES4_AT($item.index)_HOSTNAME")
                      }
                    }

                    $removed | each { remove_lease $in }
                    $added | each { add_lease $in }

                    log info $"Leases synchronized"
                  }

                  def add_lease [lease] {
                    let etcd_key = make_etcd_key $lease.hostname
                    let record = { host: $lease.ip } | to json

                    log info $"Adding record to etcd ip=($lease.ip) key=($etcd_key)"
                    ${etcd}/bin/etcdctl put $etcd_key $record
                  }

                  def remove_lease [lease] {
                    let etcd_key = make_etcd_key $lease.hostname

                    log info $"Removing record from etcd key=($etcd_key)"
                    ${etcd}/bin/etcdctl del $etcd_key
                  }

                  # Find the right etcd key for the DNS record
                  def make_etcd_key [hostname: string] {
                    $"${cfg.discovery.dns.prefix}/($hostname)"
                  }
                '';
              };
            }
          ];

          lease-database = {
            type = "memfile";
            persist = true;
            name = "/var/lib/kea/dhcp4.leases";
          };

          interfaces-config = {
            dhcp-socket-type = "raw";
            interfaces = lib.mapAttrsToList (_: network: network.interface) networks;
          };

          subnet4 = lib.map (network: {
            id = cfg.lib.toSubnetId network.id;
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
