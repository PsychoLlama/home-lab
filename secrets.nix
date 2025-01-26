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
  # Generated with: `cloudflared tunnel create <name>`
  "vpn-tunnel-key.age".publicKeys = getPublicKeysWhere (
    node: node.config.lab.profiles.vpn.server.enable
  );
}
