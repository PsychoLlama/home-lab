{ lib, nodes, ... }:

let
  # Read lab config from any node (shared via defaults)
  labConfig = (lib.head (lib.attrValues nodes)).config.lab;
  domain = labConfig.domain;
in

{
  # Zone data is referenced by tunnel.nix for CNAME records
  data.cloudflare_zone.main = {
    filter.name = domain;
  };

  # Private services now resolve via Tailscale split DNS (see tailscale.nix).
  # Only the tunnel CNAME for public ingress is created (see tunnel.nix).
}
