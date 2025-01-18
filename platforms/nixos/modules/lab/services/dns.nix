{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types mkOption;
  cfg = config.lab.services.dns;
  forward =
    upstream:

    let
      inherit (upstream) method zone;
      inherit (upstream) tls udp;
    in

    lib.getAttr method ({
      tls = ''
        forward ${zone} tls://${tls.ip} {
          tls_servername ${tls.servername}
          health_check 1h
        }
      '';

      udp = ''
        forward ${zone} ${udp.ip} {
          health_check 1h
        }
      '';

      "resolv.conf" = ''
        forward ${zone} /etc/resolv.conf
      '';
    });
in

{
  options.lab.services.dns = {
    enable = lib.mkEnableOption "Run a DNS server";

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Network interfaces to listen on. Loopback is always enabled.
      '';
    };

    server.id = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Name Server Identifier. This is sent with `OPT` records. It is
        especially useful in HA setups to disambiguate the server.

        Note: At the moment, only the `dig` client supports this feature.
      '';
    };

    discovery = {
      enable = lib.mkEnableOption "Use etcd for service discovery";
      zones = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          DNS zones to resolve using the service discovery mechanism.
        '';
      };
    };

    forward = mkOption {
      default = [ ];
      description = ''
        Forward DNS queries to other DNS servers. This is useful for resolving
        external domains or for using a DNS-over-TLS service.

        ORDER MATTERS. The first matching zone is used even if a more specific
        zone is later in the list.
      '';

      type = types.listOf (
        types.submodule {
          options.zone = mkOption {
            type = types.str;
            description = ''
              The domain pattern being forwarded. Use <literal>.</literal> to
              match all queries.
            '';
          };

          options.method = mkOption {
            type = types.enum [
              "tls"
              "udp"
              "resolv.conf"
            ];

            default = "tls";
            description = ''
              Method used to resolve queries for this zone. TLS is
              recommended.
            '';
          };

          options.tls = {
            ip = mkOption {
              type = types.str;
              description = "IP address of the DNS server";
            };

            servername = mkOption {
              type = types.str;
              description = "Hostname used for session validation";
            };
          };

          options.udp.ip = mkOption {
            type = types.str;
            description = "IP address of the DNS server";
          };
        }
      );
    };

    zone = {
      name = mkOption {
        type = types.nullOr types.str;
        example = "dc1.example.com";
        default = null;
        description = ''
          The DNS zone to serve. This is the domain name for which the server
          is authoritative. It is used to generate the zone file.
        '';
      };

      file = mkOption {
        type = types.path;
        default = pkgs.unstable.writeText "local.zone" ''
          $ORIGIN ${cfg.zone.name}.
          @       IN SOA dns trash (
                  1         ; Version number
                  60        ; Zone refresh interval
                  30        ; Zone update retry timeout
                  180       ; Zone TTL
                  3600)     ; Negative response TTL

          ; Custom records
          ${lib.concatMapStrings (record: ''
            ${record.name}  ${record.ttl} IN ${record.type} ${record.value}
          '') cfg.zone.records}
        '';

        description = ''
          Path to a BIND zone file. Setting this option will override
          the generated config.
        '';
      };

      records = mkOption {
        type = types.listOf (
          types.submodule {
            options.type = mkOption {
              type = types.str;
              description = "The type of DNS record to create";
            };

            options.name = mkOption {
              type = types.str;
              description = ''
                Any BIND zone record identifier, usually a subdomain name.
                Use <literal>@</literal> for apex records.

                Note: Only domains within the lab's zone are recognized.
              '';
            };

            options.value = mkOption {
              type = types.str;
              description = "IP addresses pointing to the service";
            };

            options.ttl = mkOption {
              type = types.str;
              description = "Length of time in seconds to cache the record";
              default = "60";
            };
          }
        );

        description = "Insert custom DNS records";
        default = [ ];
      };
    };

    hosts.file = mkOption {
      type = types.path;
      default = pkgs.emptyFile;
      description = ''
        An `/etc/hosts` structured file mapping domain names to IP addresses.
        Can be used with `pkgs.stevenblack-blocklist` for DNS-level adblock.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      # Ignore advertised DNS servers and resolve queries locally. In HA
      # setups, other nameservers may be unresponsive.
      nameservers = [ "127.0.0.1" ];

      # Expose DNS+UDP (no TCP support).
      firewall.interfaces = lib.genAttrs cfg.interfaces (_: {
        allowedUDPPorts = [ 53 ];
      });
    };

    # TODO: Split this into a separate service so it can be deployed on
    # independent hosts (HA mode).
    services.etcd = lib.mkIf cfg.discovery.enable {
      enable = true;
      package = pkgs.unstable.etcd;
    };

    services.coredns = {
      enable = true;
      package = pkgs.unstable.coredns;

      config = ''
        (common) {
          bind ${toString ([ "lo" ] ++ cfg.interfaces)}

          log
          errors
          local

          ${lib.optionalString (cfg.server.id != null) "nsid ${cfg.server.id}"}
        }

        . {
          import common
          cache

          ${lib.optionalString (cfg.zone.name != null) ''
            # WARN: This takes full control of whatever zone it's given.
            # There is no fallthrough. It will fight you.
            file ${cfg.zone.file} ${cfg.zone.name} {
              reload 0
            }
          ''}

          ${lib.optionalString cfg.discovery.enable ''
            etcd ${toString cfg.discovery.zones} {
              fallthrough
            }
          ''}

          hosts ${cfg.hosts.file} {
            fallthrough
            reload 0
            ttl 60
          }

          # Upstream DNS servers
          ${lib.concatMapStringsSep "\n" forward cfg.forward}
        }
      '';
    };
  };
}
