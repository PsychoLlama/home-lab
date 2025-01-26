let
  inherit (flake.inputs.nixpkgs) lib;
  flake = builtins.getFlake (toString ./.);
  hostKeys = lib.mapAttrs (_: node: node.config.lab.host.publicKeys) flake.outputs.colmenaHive.nodes;
in

{
  # Placeholder. No keys defined yet.
  "example.age".publicKeys = hostKeys.rpi4-003;
}
