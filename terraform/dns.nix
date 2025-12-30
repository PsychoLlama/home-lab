{ lib, nodes, ... }:

let
  # Read lab config from any node (shared via defaults)
  labConfig = (lib.head (lib.attrValues nodes)).config.lab;
  domain = labConfig.domain;

  # Find the ingress host by looking for which node has ingress enabled
  ingressHosts = lib.filterAttrs (_: node: node.config.lab.stacks.ingress.enable or false) nodes;
  ingressHostName = lib.head (lib.attrNames ingressHosts);
  virtualHosts = ingressHosts.${ingressHostName}.config.lab.stacks.ingress.virtualHosts;

  # Extract subdomain: "foo.bar.selfhosted.city" -> "foo.bar"
  subdomainOf = serverName: lib.removeSuffix ".${domain}" serverName;
in

assert lib.assertMsg (
  lib.length (lib.attrNames ingressHosts) <= 1
) "Multiple hosts have ingress enabled: ${toString (lib.attrNames ingressHosts)}";

{
  data.cloudflare_zone.main = {
    filter.name = domain;
  };

  data.tailscale_device.ingress.hostname = ingressHostName;

  resource.cloudflare_dns_record = lib.mapAttrs' (_: vhost: {
    name = subdomainOf vhost.serverName;
    value = {
      zone_id = "\${data.cloudflare_zone.main.zone_id}";
      name = subdomainOf vhost.serverName;
      type = "A";
      content = "\${data.tailscale_device.ingress.addresses[0]}";
      ttl = 300;
      proxied = false;
    };
  }) virtualHosts;
}
