{ config, lib, ... }:

let
  cfg = config.lab.services.vpn.client;
in

{
  options.lab.services.vpn.client = {
    enable = lib.mkEnableOption "the Tailscale VPN client";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;
  };
}
