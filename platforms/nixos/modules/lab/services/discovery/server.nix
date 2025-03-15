{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types;
  etcd = config.services.etcd.package;
  cfg = config.lab.services.discovery.server;
  ports = {
    client = 2379;
  };
in

{
  options.lab.services.discovery.server = {
    enable = lib.mkEnableOption "Run a discovery server";

    allowInterfaces = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Non-firewalled network interfaces allowed to reach etcd.
      '';
    };

    dns = {
      zone = lib.mkOption {
        type = types.str;
        example = "subdomain.example.com";
        description = ''
          Root-level zone where DNS records are kept. Works with subdomains.
        '';
      };

      prefix = {
        name = lib.mkOption {
          type = types.str;
          default = "dns";
          example = "/dns/com/example";
          description = ''
            Key that follows the DNS prefix for indexing individual records.
          '';
        };

        key = lib.mkOption {
          type = types.str;
          readOnly = true;
          description = ''
            Generated full path to the DNS prefix key in etcd.
          '';

          default = lib.pipe "${cfg.dns.zone}.${cfg.dns.prefix.name}." [
            # [ "example" "com" "dns" "" ]
            (lib.splitString ".")

            # [ "" "dns" "com" "example"  ]
            (lib.reverseList)

            # "/dns/com/example"
            (lib.concatStringsSep "/")
          ];
        };

        host = {
          name = lib.mkOption {
            type = types.str;
            default = "host";
            description = ''
              Key that follows the DNS prefix for indexing individual hosts.
            '';
          };

          key = lib.mkOption {
            type = types.str;
            readOnly = true;
            example = "/dns/com/example/hosts";
            description = ''
              Generated full prefix key for host records in etcd.
            '';

            default = "${cfg.dns.prefix.key}/${cfg.dns.prefix.host.name}";
          };
        };
      };
    };

    static-values = lib.mkOption {
      default = [ ];
      description = ''
        Values to add every time the discovery server starts.

        WARNING: Old values are not removed. They must be purged manually.
      '';

      type = types.listOf (
        types.submodule (
          { config, ... }:
          {
            options.key = lib.mkOption {
              type = types.str;
              example = "/arbitrary/key";
              description = ''
                Where to store the data.
              '';
            };

            options.value = lib.mkOption {
              type = types.either types.str types.path;
              example = "value";
              description = ''
                Arbitrary value to store.
              '';

              apply = value: if lib.isString value then pkgs.writeText "etcd-content" value else value;
            };

            options.command = lib.mkOption {
              type = types.str;
              readOnly = true;
              description = ''
                Generated command that updates etcd.
              '';

              default = ''
                ${etcd}/bin/etcdctl put -- ${config.key} < ${config.value}
              '';
            };
          }
        )
      );
    };
  };

  # TODO:
  # - Add a client service daemon that performs healthchecks and updates etcd.
  config = lib.mkIf cfg.enable {
    services.etcd = {
      enable = true;
      package = pkgs.etcd;
      extraConf = {
        # Bind to all interfaces. Highly discouraged, but it's my LAN.
        LISTEN_CLIENT_URLS = "http://0.0.0.0:${toString ports.client}";
      };
    };

    # Add static values as soon as the service is ready.
    systemd.services.etcd.postStart =
      lib.concatMapStringsSep "\n" (lib.getAttr "command")
        cfg.static-values;

    # Open the firewall for etcd.
    networking.firewall.interfaces = lib.genAttrs cfg.allowInterfaces (_: {
      allowedTCPPorts = [ ports.client ];
    });
  };
}
