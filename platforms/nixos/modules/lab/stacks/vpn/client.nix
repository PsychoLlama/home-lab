{ config, lib, ... }:

let
  cfg = config.lab.stacks.vpn.client;
in

{
  options.lab.stacks.vpn.client = {
    enable = lib.mkEnableOption "Enable the VPN client stack";

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Tailscale ACL tags to advertise.";
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client = {
      enable = true;
      inherit (cfg) tags;
    };
  };
}
