{ config, lib, ... }:

let
  cfg = config.lab.services.vpn.client;
in

{
  options.lab.services.vpn.client = {
    enable = lib.mkEnableOption "the Tailscale VPN client";

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Tailscale ACL tags to advertise.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      extraUpFlags =
        let
          baseTags = [ "lab" config.lab.datacenter ];
          allTags = baseTags ++ cfg.tags;
          tagList = lib.concatMapStringsSep "," (t: "tag:${t}") allTags;
        in
        [ "--advertise-tags=${tagList}" ];
    };
  };
}
