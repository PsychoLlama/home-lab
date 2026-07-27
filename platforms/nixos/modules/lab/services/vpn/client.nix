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

      # OAuth client secrets register ephemeral nodes by default, which the
      # control plane purges after a node is offline past a timeout. A single
      # extended outage (e.g. an ISP blip) then silently deletes every lab node
      # from the tailnet. Force non-ephemeral registration so nodes persist
      # across outages. preauthorized skips manual device approval.
      authKeyParameters = {
        ephemeral = false;
        preauthorized = true;
      };

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

    # tailscaled reads the host's base resolver once at startup and never
    # re-reads it. It also registers itself with resolvconf exclusively, so
    # the merged `/etc/resolv.conf` lists only tailscaled, which it discards
    # as a loop. Starting before the DHCP client therefore leaves it with no
    # upstreams permanently: every name outside the tailnet SERVFAILs until
    # something re-triggers the config, and a host that builds on itself
    # can't resolve the binary cache.
    #
    # dhcpcd is `Type=forking`, so `network-online.target` is only reached
    # once the lease is in and the resolvconf record is written.
    #
    # Hosts that set `networking.nameservers` get a static resolvconf record
    # from early boot and never race. Ordering them here would stall
    # tailscaled behind a WAN lease, and on a router it would drag CoreDNS
    # (which starts after tailscaled) along with it — leaving the LAN
    # without DNS during an ISP outage, exactly when it's least welcome.
    systemd.services.tailscaled = lib.mkIf (config.networking.nameservers == [ ]) {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };

    # Exit nodes require IP forwarding
    boot.kernel.sysctl = lib.mkIf cfg.exitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
