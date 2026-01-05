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

  # Generate Caddyfile from virtualHosts
  mkVhost =
    _: vhost:
    let
      proxyOpts = lib.optionalString (vhost.insecure || vhost.streaming) ''
        {
          ${lib.optionalString vhost.streaming "flush_interval -1"}
          transport http {
            ${lib.optionalString vhost.insecure "tls_insecure_skip_verify"}
            ${lib.optionalString vhost.streaming ''
              read_timeout 0
              write_timeout 0''}
          }
        }'';
    in
    ''
      ${vhost.serverName} {
        log
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy ${vhost.backend}${
          lib.optionalString (vhost.insecure || vhost.streaming) " "
        }${proxyOpts}
      }
    '';

  caddyfile = pkgs.writeText "Caddyfile" (
    lib.concatStringsSep "\n" (lib.mapAttrsToList mkVhost cfg.virtualHosts)
  );
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
      configFile = caddyfile;
    };

    systemd.services.caddy.serviceConfig.EnvironmentFile = config.age.secrets.cloudflare-api-token.path;
  };
}
