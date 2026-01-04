{
  lib,
  formats,
  nodes,
}:

let
  json = formats.json { };

  # Read lab config from any node (shared via defaults)
  labConfig = (lib.head (lib.attrValues nodes)).config.lab;

  # Find nodes by enabled features
  vpnNodes = lib.filterAttrs (_: node: node.config.lab.services.vpn.client.enable) nodes;
  ingressHosts = lib.filterAttrs (_: node: node.config.lab.services.ingress.enable) nodes;
  routerHosts = lib.filterAttrs (_: node: node.config.lab.stacks.router.enable) nodes;
  tunnelHosts = lib.filterAttrs (_: node: node.config.lab.services.tunnel.enable) nodes;

  # Extract virtualHosts from the ingress host
  ingressHostName = lib.head (lib.attrNames ingressHosts);
  virtualHosts = ingressHosts.${ingressHostName}.config.lab.services.ingress.virtualHosts;

  # Extract tunnel hosts (if any)
  tunnelHostName = if tunnelHosts != { } then lib.head (lib.attrNames tunnelHosts) else null;
  tunnelHostsConfig =
    if tunnelHostName != null then
      tunnelHosts.${tunnelHostName}.config.lab.services.tunnel.hosts
    else
      { };
in

json.generate "terraform-config.json" {
  lab = {
    inherit (labConfig) domain datacenter;
  };

  router = {
    hostName = lib.head (lib.attrNames routerHosts);
  };

  vpn = {
    nodes = lib.mapAttrs (_: node: { inherit (node.config.lab.services.vpn.client) tags; }) vpnNodes;
  };

  ingress = {
    private = lib.mapAttrs (_: vhost: { inherit (vhost) backend targetTag; }) virtualHosts;

    public = lib.mapAttrs (_: host: {
      inherit (host) service path;
      tlsVerify = host.tls.verify;
    }) tunnelHostsConfig;
  };
}
