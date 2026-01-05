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

  # Parse backend URL to extract dial address
  # Handles both "host:port" and "https://host:port" formats
  parseBackend =
    backend:
    let
      isHttps = lib.hasPrefix "https://" backend;
      stripped = lib.removePrefix "https://" (lib.removePrefix "http://" backend);
    in
    {
      dial = stripped;
      inherit isHttps;
    };

  # Generate a route for a virtualHost
  mkRoute =
    _: vhost:
    let
      backend = parseBackend vhost.backend;
      needsTls = vhost.insecure || backend.isHttps;
      needsTransport = needsTls || vhost.streaming;
      transport = lib.optionalAttrs needsTransport (
        {
          protocol = "http";
        }
        // lib.optionalAttrs needsTls {
          tls.insecure_skip_verify = vhost.insecure;
        }
        // lib.optionalAttrs vhost.streaming {
          read_timeout = 0;
          write_timeout = 0;
        }
      );
      handler = {
        handler = "reverse_proxy";
        upstreams = [ { dial = backend.dial; } ];
      }
      // lib.optionalAttrs vhost.streaming { flush_interval = -1; }
      // lib.optionalAttrs (transport != { }) { inherit transport; };
    in
    {
      match = [ { host = [ vhost.serverName ]; } ];
      handle = [ handler ];
    };

  # Collect all server names for TLS policy
  allServerNames = lib.mapAttrsToList (_: vhost: vhost.serverName) cfg.virtualHosts;
in

{
  options.lab.services.ingress = {
    enable = lib.mkEnableOption "Caddy reverse proxy with automatic HTTPS";

    virtualHosts = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            serverName = lib.mkOption {
              type = lib.types.str;
              description = "FQDN for this virtual host";
            };
            backend = lib.mkOption {
              type = lib.types.str;
              description = "Backend URL to proxy to";
            };
            insecure = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Skip TLS verification for HTTPS backends";
            };
            streaming = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable streaming mode for WebSocket/SSE backends (disables timeouts)";
            };
            targetTag = lib.mkOption {
              type = lib.types.str;
              description = "Tailscale ACL tag for the backend service (used by Terraform for firewall grants)";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.cloudflare-api-token.file = ./cloudflare-api-token.age;

    services.caddy = {
      enable = true;
      package = caddyWithCloudflare;

      settings = {
        apps = {
          http.servers.main = {
            listen = [ ":443" ];
            routes = lib.mapAttrsToList mkRoute cfg.virtualHosts;
          };

          tls.automation.policies = [
            {
              subjects = allServerNames;
              issuers = [
                {
                  module = "acme";
                  challenges.dns.provider = {
                    name = "cloudflare";
                    api_token = "{env.CLOUDFLARE_API_TOKEN}";
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
