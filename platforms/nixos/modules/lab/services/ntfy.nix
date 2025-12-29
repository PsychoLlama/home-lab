{ config, lib, ... }:

let
  cfg = config.lab.services.ntfy;
  port = 2586;
in

{
  options.lab.services.ntfy = {
    enable = lib.mkEnableOption "ntfy-sh push notification server";
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ "ntfy" ];

    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://ntfy.${config.lab.domain}";
        listen-http = "0.0.0.0:${toString port}";
      };
    };
  };
}
