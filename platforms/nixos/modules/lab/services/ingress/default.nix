{ config, lib, pkgs, ... }:

let
  cfg = config.lab.services.ingress;

  # Build Caddy with Cloudflare DNS plugin
  caddyWithCloudflare = pkgs.caddy.withPlugins {
    plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
    hash = "sha256-ea8PC/+SlPRdEVVF/I3c1CBprlVp1nrumKM5cMwJJ3U=";
  };

  # Generate Caddyfile from virtualHosts
  caddyfile = pkgs.writeText "Caddyfile" (lib.concatStringsSep "\n\n" (
    lib.mapAttrsToList (_: vhost: ''
      ${vhost.serverName} {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy ${vhost.backend}
      }
    '') cfg.virtualHosts
  ));
in

{
  options.lab.services.ingress = {
    enable = lib.mkEnableOption "Caddy reverse proxy with automatic HTTPS";

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          serverName = lib.mkOption {
            type = lib.types.str;
            description = "FQDN for this virtual host";
          };
          backend = lib.mkOption {
            type = lib.types.str;
            description = "Backend URL to proxy to";
          };
        };
      });
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.cloudflare-api-token.file = ./cloudflare-api-token.age;

    services.caddy = {
      enable = true;
      package = caddyWithCloudflare;
      configFile = caddyfile;
    };

    systemd.services.caddy.serviceConfig.EnvironmentFile =
      config.age.secrets.cloudflare-api-token.path;

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
  };
}
