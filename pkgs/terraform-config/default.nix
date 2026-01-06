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

  # Collect prometheus scrape targets from all nodes
  # Each target has: tag (ACL tag), port (prometheus port)
  collectTargets =
    let
      nodeTargets = lib.flatten (
        map (
          node:
          let
            cfg = node.config;
            svc = cfg.lab.services;
            stk = cfg.lab.stacks;
          in
          # Node exporter (all nodes)
          lib.optional svc.node-exporter.enable {
            tag = svc.node-exporter.prometheus.acl.tag;
            port = svc.node-exporter.prometheus.port;
          }
          # CoreDNS
          ++ lib.optional (svc.dns.enable && svc.dns.prometheus.enable) {
            tag = svc.dns.prometheus.acl.tag;
            port = svc.dns.prometheus.port;
          }
          # Kea DHCP
          ++ lib.optional (svc.dhcp.enable && svc.dhcp.prometheus.enable) {
            tag = svc.dhcp.prometheus.acl.tag;
            port = svc.dhcp.prometheus.port;
          }
          # etcd discovery server
          ++ lib.optional svc.discovery.server.enable {
            tag = svc.discovery.server.prometheus.acl.tag;
            port = svc.discovery.server.prometheus.port;
          }
          # Caddy ingress
          ++ lib.optional (svc.ingress.enable && svc.ingress.prometheus.enable) {
            tag = svc.ingress.prometheus.acl.tag;
            port = svc.ingress.prometheus.port;
          }
          # ntfy
          ++ lib.optional (svc.ntfy.enable && svc.ntfy.prometheus.enable) {
            tag = svc.ntfy.prometheus.acl.tag;
            port = svc.ntfy.prometheus.port;
          }
          # Home Assistant
          ++ lib.optional stk.home-automation.enable {
            tag = stk.home-automation.prometheus.acl.tag;
            port = stk.home-automation.prometheus.port;
          }
          # Syncthing (file-server stack)
          ++ lib.optional (stk.file-server.enable && cfg.services.syncthing.enable) {
            tag = stk.file-server.prometheus.acl.tag;
            port = stk.file-server.prometheus.syncthing.port;
          }
          # Gitea
          ++ lib.optional (svc.gitea.enable && svc.gitea.prometheus.enable) {
            tag = svc.gitea.prometheus.acl.tag;
            port = svc.gitea.prometheus.port;
          }
          # Gickup
          ++ lib.optional svc.gickup.enable {
            tag = svc.gickup.prometheus.acl.tag;
            port = svc.gickup.prometheus.port;
          }
        ) (lib.attrValues nodes)
      );

      # Group targets by tag and collect unique ports
      groupedByTag = lib.groupBy (t: t.tag) nodeTargets;
    in
    lib.mapAttrs (_: targets: lib.unique (map (t: t.port) targets)) groupedByTag;

  monitoringGrants = collectTargets;
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

  # Monitoring grants: tag -> list of ports
  # Used by Terraform to generate ACL grants for prometheus scraping
  monitoring.grants = monitoringGrants;
}
