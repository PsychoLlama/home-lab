{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.lab.services.tunnel;
in

{
  options.lab.services.tunnel = {
    enable = lib.mkEnableOption "Cloudflare Tunnel for public ingress";

    # Hosts are defined here for Terraform to read, but ingress is managed
    # remotely via cloudflare_zero_trust_tunnel_cloudflared_config.
    hosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Subdomain name (inferred from attribute key)";
              };
              service = lib.mkOption {
                type = lib.types.str;
                description = "Backend service URL (e.g., http://rpi4-002:8123)";
              };
              path = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Optional path regex to match (e.g., /api/webhook/.*)";
              };
              tls.verify = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Verify TLS certificates for HTTPS backends";
              };
              acl.tag = lib.mkOption {
                type = lib.types.str;
                description = "Tailscale ACL tag for the backend service";
              };
            };
          }
        )
      );
      default = { };
      description = "Public endpoints to expose via Cloudflare Tunnel";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.cloudflare-tunnel-token.file = ./cloudflare-tunnel-token.age;

    # Token-based tunnel (remotely-managed ingress via Terraform)
    systemd.services.cloudflared-tunnel = {
      description = "Cloudflare Tunnel";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = pkgs.writeShellScript "cloudflared-tunnel" ''
          exec ${pkgs.cloudflared}/bin/cloudflared tunnel \
            --no-autoupdate \
            run --token "$(cat $CREDENTIALS_DIRECTORY/token)"
        '';
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        LoadCredential = "token:${config.age.secrets.cloudflare-tunnel-token.path}";
      };
    };
  };
}
