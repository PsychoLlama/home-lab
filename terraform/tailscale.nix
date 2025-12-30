{ lib, nodes, ... }:

let
  # Find the ingress host by looking for which node has ingress enabled
  ingressHosts = lib.filterAttrs (_: node: node.config.lab.stacks.ingress.enable or false) nodes;
  ingressHostName = lib.head (lib.attrNames ingressHosts);
  virtualHosts = ingressHosts.${ingressHostName}.config.lab.stacks.ingress.virtualHosts;

  # Client device tags (not managed by NixOS, but referenced in grants)
  clientTags = [
    "laptop"
    "mobile"
  ];

  # Nodes with VPN enabled (for device tag management)
  vpnNodes = lib.filterAttrs (_: node: node.config.lab.services.vpn.client.enable) nodes;

  # Collect all unique tags from all hosts
  hostTags = lib.pipe vpnNodes [
    lib.attrValues
    (map (
      node:
      node.config.lab.services.vpn.client.tags
      ++ [
        "lab"
        node.config.lab.datacenter
      ]
    ))
    lib.flatten
    lib.unique
  ];

  allTags = lib.unique (clientTags ++ hostTags);

  # Parse backend "host:port" or "https://host:port" -> { host, port }
  parseBackend =
    backend:
    let
      stripped = lib.removePrefix "https://" (lib.removePrefix "http://" backend);
      parts = lib.splitString ":" stripped;
    in
    {
      host = lib.elemAt parts 0;
      port = lib.elemAt parts 1;
    };

  # Generate ingress->backend grants from virtualHosts
  ingressGrants = lib.mapAttrsToList (
    _: vhost:
    let
      parsed = parseBackend vhost.backend;
    in

    {
      src = [ "tag:ingress" ];
      dst = [ "tag:${vhost.targetTag}" ];
      ip = [ parsed.port ];
    }
  ) virtualHosts;
in

{
  resource.tailscale_acl.primary.acl = lib.strings.toJSON {
    tagOwners = lib.genAttrs (map (t: "tag:${t}") allTags) (tag: [
      "autogroup:admin"
      tag
    ]);

    grants = ingressGrants ++ [
      # Home Assistant -> ingress for ntfy-sh webhooks
      {
        src = [ "tag:home-automation" ];
        dst = [ "tag:ingress" ];
        ip = [ "443" ];
      }

      # Monitoring access (scrape all lab nodes on exporter ports)
      {
        src = [ "tag:monitoring" ];
        dst = [ "tag:lab" ];

        # Prometheus, node-exporter, CoreDNS
        ip = [
          "9090"
          "9100"
          "9153"
        ];
      }

      # Devices managed outside the home lab.
      {
        src = [ "tag:laptop" ];
        dst = [ "*" ];
        ip = [ "*" ];
      }

      {
        src = [ "tag:mobile" ];
        dst = [ "tag:ingress" ];
        ip = [
          "80"
          "443"
        ];
      }
    ];

    ssh = [
      {
        action = "accept";
        src = [ "tag:laptop" ];
        dst = [ "tag:lab" ];
        users = [ "root" ];
      }
    ];
  };

  # Look up each VPN-enabled device by hostname
  data.tailscale_device = lib.mapAttrs (hostname: _: {
    inherit hostname;
  }) vpnNodes;

  # Apply tags to each device via Terraform (instead of --advertise-tags)
  resource.tailscale_device_tags = lib.mapAttrs (
    name: node:

    {
      device_id = "\${data.tailscale_device.${name}.id}";
      tags = map (t: "tag:${t}") (
        node.config.lab.services.vpn.client.tags
        ++ [
          "lab"
          node.config.lab.datacenter
        ]
      );
    }) vpnNodes;
}
