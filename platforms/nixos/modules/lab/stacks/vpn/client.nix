{ config, lib, ... }:

let
  cfg = config.lab.stacks.vpn.client;
in

{
  options.lab.stacks.vpn.client = {
    enable = lib.mkEnableOption "Enable the VPN client stack";
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.enable = true;
  };
}
