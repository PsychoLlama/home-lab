let
  inherit (flake.inputs.nixpkgs) lib;
  flake = builtins.getFlake (toString ./.);

  # Personal key for decrypting/editing secrets locally.
  adminKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHAMADENOb8Pe0kysfLc6BxK2VUiPMt57IOaDYa7J/M5";

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

  /**
    Build the full key list for a secret: admin key + matching node keys.
  */
  keysFor = predicate: [ adminKey ] ++ getPublicKeysWhere predicate;
in

{
  # Tailscale OAuth client secret for automatic node authentication.
  # Create at: https://login.tailscale.com/admin/settings/oauth
  # Scope: auth_keys (write), with tags containing all lab node tags.
  "platforms/nixos/modules/lab/services/vpn/tailscale-oauth.age".publicKeys = keysFor (
    node: node.config.lab.services.vpn.client.enable
  );

  # Cloudflare API token for ACME DNS-01 challenge.
  # Create at: https://dash.cloudflare.com/profile/api-tokens
  # Permissions: Zone DNS Edit + Zone Read for selfhosted.city
  "platforms/nixos/modules/lab/services/ingress/cloudflare-api-token.age".publicKeys = keysFor (
    node: node.config.lab.services.ingress.enable
  );

  # Restic REST server htpasswd file for client authentication.
  # Generate entries with: htpasswd -nB workstation-hostname
  "platforms/nixos/modules/lab/services/restic-server/restic-htpasswd.age".publicKeys = keysFor (
    node: node.config.lab.services.restic-server.enable
  );

  # Home Assistant long-lived access token for Prometheus scraping.
  # Create at: HA Profile → Long-Lived Access Tokens
  "platforms/nixos/modules/lab/stacks/observability/ha-prometheus-token.age".publicKeys = keysFor (
    node: node.config.lab.stacks.observability.enable
  );

  # Cloudflare Tunnel token for public ingress.
  "platforms/nixos/modules/lab/services/tunnel/cloudflare-tunnel-token.age".publicKeys = keysFor (
    node: node.config.lab.services.tunnel.enable
  );

  # GitHub fine-grained token for Gickup to read repositories.
  # Create at: https://github.com/settings/personal-access-tokens/new
  # Repository access: All repositories, Permissions: Contents (read-only)
  "platforms/nixos/modules/lab/services/gickup/github-token.age".publicKeys = keysFor (
    node: node.config.lab.services.gickup.enable
  );

  # Gitea API token for Gickup to create/update mirrors.
  # Create in Gitea: Settings → Applications → Generate New Token
  "platforms/nixos/modules/lab/services/gickup/gitea-token.age".publicKeys = keysFor (
    node: node.config.lab.services.gickup.enable
  );
}
