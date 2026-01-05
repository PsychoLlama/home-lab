{
  config,
  lib,
  nodes,
  ...
}:

let
  cfg = config.lab.stacks.ingress.private;
in

{
  options.lab.stacks.ingress.private = {
    enable = lib.mkEnableOption "private ingress stack (Caddy + VPN)";

    acl.tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "ingress";
      description = "Tailscale ACL tag for this stack";
    };
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client = {
      enable = true;
      tags = [ cfg.acl.tag ];
    };

    lab.services.ingress = {
      enable = true;
      prometheus.enable = true;

      hosts."grafana.selfhosted.city" = {
        backend = "rpi4-002:3000";
        acl.tag = nodes.rpi4-002.config.lab.stacks.observability.acl.tag;
      };

      hosts."syncthing.selfhosted.city" = {
        backend = "nas-001:8384";
        acl.tag = nodes.nas-001.config.lab.stacks.file-server.acl.tag;
      };

      hosts."restic.selfhosted.city" = {
        backend = "nas-001:8000";
        acl.tag = nodes.nas-001.config.lab.stacks.file-server.acl.tag;
      };

      hosts."home.selfhosted.city" = {
        backend = "rpi4-002:8123";
        acl.tag = nodes.rpi4-002.config.lab.stacks.home-automation.acl.tag;
      };

      hosts."unifi.selfhosted.city" = {
        backend = "rpi4-001:8443";
        acl.tag = nodes.rpi4-001.config.lab.stacks.router.acl.tag;
        tls.verify = false;
      };

      hosts."ntfy.selfhosted.city" = {
        backend = "rpi4-002:2586";
        acl.tag = nodes.rpi4-002.config.lab.services.ntfy.acl.tag;
        streaming = true;
      };
    };
  };
}
