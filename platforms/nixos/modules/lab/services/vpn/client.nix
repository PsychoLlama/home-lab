{ config, lib, ... }:

let
  cfg = config.lab.services.vpn.client;
in

{
  options.lab.services.vpn.client = {
    enable = lib.mkEnableOption "the Tailscale VPN client";

    exitNode = lib.mkEnableOption "advertising this device as an exit node";

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Tailscale ACL tags to advertise.";
    };

    acl.tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "exit-node";
      description = "Tailscale ACL tag for exit nodes";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.tailscale-oauth.file = ./tailscale-oauth.age;

    # Add exit-node tag when enabled
    lab.services.vpn.client.tags = lib.mkIf cfg.exitNode [ cfg.acl.tag ];

    services.tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale-oauth.path;
      extraUpFlags =
        let
          # Minimal tags for initial auth - Terraform manages the full set
          tagList = lib.concatMapStringsSep "," (t: "tag:${t}") [
            "lab"
            config.lab.datacenter
          ];
        in
        [ "--advertise-tags=${tagList}" ] ++ lib.optionals cfg.exitNode [ "--advertise-exit-node" ];
    };

    # Exit nodes require IP forwarding
    boot.kernel.sysctl = lib.mkIf cfg.exitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
