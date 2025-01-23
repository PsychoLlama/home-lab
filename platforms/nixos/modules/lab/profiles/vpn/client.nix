{ config, lib, ... }:

let
  cfg = config.lab.profiles.vpn.client;
in

{
  options.lab.profiles.vpn.client = {
    enable = lib.mkEnableOption ''
      Enable the VPN client.

      This requires manual setup. The first time the host comes online, run:
      $ tailscale up --auth-key <auth_key> --login-server <server_url>
    '';
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;

    # TODO: Provision the key and init the VPN automatically.
    # See `authKeyParameters` and `authKeyFile`.
  };
}
