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

    ttl = mkOption {
      type = types.str;
      default = "60";
      description = "Default TTL for DNS records";
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

    prometheus = {
      enable = lib.mkEnableOption "Enable Prometheus metrics exporter";
      port = mkOption {
        type = types.int;
        default = 9153;
        description = "Port to expose Prometheus metrics";
      };
      acl.tag = mkOption {
        type = types.str;
        readOnly = true;
        default = "router";
        description = "Tailscale ACL tag for monitoring access";
      };
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

      dns.prefix = lib.mkOption {
        type = types.str;
        description = ''
          Etcd key prefix where DNS records are stored.
          Uses reverse scheme, e.g. `/dns/com/example/subdomain`.
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

    zones = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options.records = mkOption {
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
                    '';
                  };

                  options.value = mkOption {
                    type = types.str;
                    description = "IP addresses pointing to the service";
                  };

                  options.ttl = mkOption {
                    type = types.str;
                    description = "Length of time in seconds to cache the record";
                    default = cfg.ttl;
                  };
                }
              );

              description = "DNS records for this zone";
              default = [ ];
            };

            options.file = mkOption {
              type = types.path;
              readOnly = true;
              default = pkgs.unstable.writeText "${name}.zone" ''
                $ORIGIN ${name}.
                @       IN SOA dns trash (
                        1         ; Version number
                        60        ; Zone refresh interval
                        30        ; Zone update retry timeout
                        180       ; Zone TTL
                        3600)     ; Negative response TTL

                ; Custom records
                ${lib.concatMapStrings (record: ''
                  ${record.name}  ${record.ttl} IN ${record.type} ${record.value}
                '') cfg.zones.${name}.records}
              '';

              description = ''
                Path to a BIND zone file. Setting this option will override
                the generated config.
              '';
            };
          }
        )
      );

      default = { };
      description = ''
        DNS zones to serve. Each attribute name is the zone name (e.g.,
        "example.com") and the value contains the zone configuration.
      '';
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
    # Ensure CoreDNS starts after Tailscale so the interface has its IPv4 address.
    # CoreDNS caches interface addresses at startup and won't rebind later.
    systemd.services.coredns = lib.mkIf (lib.elem "tailscale0" cfg.interfaces) {
      wants = [ "tailscaled.service" ];
      after = [ "tailscaled.service" ];
    };

    networking = {
      # Ignore advertised DNS servers and resolve queries locally. In HA
      # setups, other nameservers may be unresponsive.
      nameservers = [ "127.0.0.1" ];

      # Expose DNS+UDP (no TCP support).
      firewall.interfaces = lib.genAttrs cfg.interfaces (_: {
        allowedUDPPorts = [ 53 ];
        allowedTCPPorts = lib.mkIf cfg.prometheus.enable [
          cfg.prometheus.port
        ];
      });
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

        ${lib.optionalString cfg.discovery.enable ''
          # Discovery zones get their own server block to avoid being
          # shadowed by wildcard zones in parent domains.
          ${toString cfg.discovery.zones} {
            import common
            cache ${cfg.ttl}

            etcd {
              path ${cfg.discovery.dns.prefix}
              fallthrough
            }

            ${lib.concatMapStringsSep "\n" forward cfg.forward}
          }
        ''}

        ${lib.concatStrings (
          lib.mapAttrsToList (zoneName: zone: ''
            # Zone server block for ${zoneName}
            ${zoneName} {
              import common
              cache ${cfg.ttl}

              file ${zone.file} {
                reload 0
              }

              ${lib.concatMapStringsSep "\n" forward cfg.forward}
            }
          '') cfg.zones
        )}

        . {
          import common
          cache ${cfg.ttl}

          ${lib.optionalString cfg.prometheus.enable ''
            prometheus 0.0.0.0:${toString cfg.prometheus.port}
          ''}

          hosts ${cfg.hosts.file} {
            fallthrough
            reload 0
            ttl ${cfg.ttl}
          }

          # Upstream DNS servers
          ${lib.concatMapStringsSep "\n" forward cfg.forward}
        }
      '';
    };
  };
}
