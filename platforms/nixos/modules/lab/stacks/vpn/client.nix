{ config, lib, ... }:

let
  cfg = config.lab.stacks.vpn.client;
in

{
  options.lab.stacks.vpn.client = {
    enable = lib.mkEnableOption "Enable the VPN client stack";

    exitNode = lib.mkEnableOption "advertising this device as an exit node";

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Tailscale ACL tags to advertise.";
    };

    acl.tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = config.lab.services.vpn.client.acl.tag;
      description = "Tailscale ACL tag for exit nodes";
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client = {
      enable = true;
      inherit (cfg) tags exitNode;
    };
  };
}
