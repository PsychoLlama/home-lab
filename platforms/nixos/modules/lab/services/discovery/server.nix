{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types;
  cfg = config.lab.services.discovery.server;
in

{
  options.lab.services.discovery.server = {
    enable = lib.mkEnableOption "Run a discovery server";

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
  };

  # TODO:
  # - Install post-hook to update etcd with static records
  # - Expose this to the network (yolo)
  config = lib.mkIf cfg.enable {
    services.etcd = {
      enable = true;
      package = pkgs.unstable.etcd;
    };
  };
}
