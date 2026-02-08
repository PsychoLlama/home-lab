{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.lab.services.ingress;

  # Build Caddy with Cloudflare DNS plugin
  caddyWithCloudflare = pkgs.caddy.withPlugins {
    plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
    hash = "sha256-ea8PC/+SlPRdEVVF/I3c1CBprlVp1nrumKM5cMwJJ3U=";
  };

  # Recursively remove null values from an attrset
  withoutNulls = lib.filterAttrsRecursive (_: v: v != null);

  # Generate a Caddy route for a host.
  # Output shape (nulls filtered):
  #   { match: [{ host: [string] }], handle: [{ handler, upstreams, transport?, flush_interval? }] }
  mkRoute =
    _: host:
    let
      useTls = host.tls.verify != null;
      needsTransport = useTls || host.streaming;
    in
    withoutNulls {
      match = [ { host = [ host.name ]; } ];
      handle = [
        (withoutNulls {
          handler = "reverse_proxy";
          upstreams = [ { dial = host.backend; } ];
          flush_interval = if host.streaming then -1 else null;
          transport =
            if needsTransport then
              withoutNulls {
                protocol = "http";
                tls = if useTls then { insecure_skip_verify = !host.tls.verify; } else null;
                read_timeout = if host.streaming then 0 else null;
                write_timeout = if host.streaming then 0 else null;
              }
            else
              null;
        })
      ];
    };

  # Collect all server names for TLS policy
  allServerNames = lib.mapAttrsToList (_: host: host.name) cfg.hosts;
in

{
  options.lab.services.ingress = {
    enable = lib.mkEnableOption "Caddy reverse proxy with automatic HTTPS";

    prometheus = {
      enable = lib.mkEnableOption "Expose Prometheus metrics on :2019";
      port = lib.mkOption {
        type = lib.types.int;
        readOnly = true;
        default = 2019;
        description = "Port for Caddy Prometheus metrics";
      };
      acl.tag = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "ingress";
        description = "Tailscale ACL tag for monitoring access";
      };
    };

    hosts = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "FQDN for this host (defaults to attribute name)";
              };
              backend = lib.mkOption {
                type = lib.types.str;
                description = "Backend address as host:port";
              };
              tls.verify = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = null;
                description = "TLS verification for backend: null = no TLS, true = verify, false = skip verification";
              };
              streaming = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable streaming mode for WebSocket/SSE backends (disables timeouts)";
              };
              acl.tag = lib.mkOption {
                type = lib.types.str;
                description = "Tailscale ACL tag for the backend service (used by Terraform for firewall grants)";
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.cloudflare-api-token.file = ./cloudflare-api-token.age;

    services.caddy = {
      enable = true;
      package = caddyWithCloudflare;

      settings = {
        admin = lib.mkIf cfg.prometheus.enable {
          listen = "0.0.0.0:2019";
          origins = [ "0.0.0.0:2019" ];
        };

        apps = {
          http.servers.main = {
            listen = [ ":443" ];
            routes = lib.mapAttrsToList mkRoute cfg.hosts;
          };

          tls.automation.policies = [
            {
              subjects = allServerNames;
              issuers = [
                {
                  module = "acme";
                  challenges.dns = {
                    provider = {
                      name = "cloudflare";
                      api_token = "{env.CLOUDFLARE_API_TOKEN}";
                    };
                    # Use public resolvers for ACME propagation checks.
                    # The default system resolver (Tailscale MagicDNS)
                    # follows CNAMEs into .ts.net which returns NOTIMP.
                    resolvers = [ "1.1.1.1" ];
                  };
                }
              ];
            }
          ];
        };
      };
    };

    systemd.services.caddy.serviceConfig.EnvironmentFile = config.age.secrets.cloudflare-api-token.path;
  };
}
