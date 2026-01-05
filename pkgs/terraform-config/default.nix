{
  lib,
  formats,
  nodes,
}:

let
  json = formats.json { };

  # Find all nodes matching a predicate
  findNodesWhere = pred: lib.filter pred (lib.attrValues nodes);

  # Find exactly one node matching a predicate (asserts if != 1 match)
  findSingleNode =
    pred:
    let
      matches = findNodesWhere pred;
    in
    assert lib.length matches == 1;
    lib.head matches;

  # Read lab config from any node (shared via defaults)
  labConfig = (lib.head (lib.attrValues nodes)).config.lab;

  # Find nodes by enabled features
  vpnNodes = findNodesWhere (node: node.config.lab.services.vpn.client.enable);

  services = {
    ingress = findSingleNode (node: node.config.lab.services.ingress.enable);
    tunnel = findSingleNode (node: node.config.lab.services.tunnel.enable);
    router = findSingleNode (node: node.config.lab.stacks.router.enable);
  };
in

json.generate "terraform-config.json" {
  lab = {
    inherit (labConfig) domain datacenter;
  };

  router = {
    hostName = services.router.config.networking.hostName;
  };

  vpn = {
    nodes = lib.listToAttrs (
      map (node: {
        name = node.config.networking.hostName;
        value = { inherit (node.config.lab.services.vpn.client) tags; };
      }) vpnNodes
    );
  };

  ingress = {
    private = lib.mapAttrs (_: host: {
      inherit (host) backend;
      acl.tag = host.acl.tag;
    }) services.ingress.config.lab.services.ingress.hosts;

    public = lib.mapAttrs (_: host: {
      inherit (host) service path;
      tlsVerify = host.tls.verify;
    }) services.tunnel.config.lab.services.tunnel.hosts;
  };
}
