let
  inherit (flake.inputs.nixpkgs) lib;
  flake = builtins.getFlake (toString ./.);

  /**
    Find all public keys for nodes that match the given predicate.
  */
  getPublicKeysWhere =
    predicate:
    lib.pipe flake.outputs.colmenaHive.nodes [
      (lib.filterAttrs (_: node: predicate node))
      (lib.mapAttrsToList (_: node: node.config.lab.host.publicKeys))
      (lib.flatten)
    ];
in

{
  # Tailscale OAuth client secret for automatic node authentication.
  # Create at: https://login.tailscale.com/admin/settings/oauth
  # Scope: auth_keys (write), with tags containing all lab node tags.
  "tailscale-oauth.age".publicKeys = getPublicKeysWhere (
    node: node.config.lab.services.vpn.client.enable
  );

  # Cloudflare API token for ACME DNS-01 challenge.
  # Create at: https://dash.cloudflare.com/profile/api-tokens
  # Permissions: Zone DNS Edit + Zone Read for selfhosted.city
  "cloudflare-api-token.age".publicKeys = getPublicKeysWhere (
    node: node.config.lab.services.ingress.enable
  );
}
