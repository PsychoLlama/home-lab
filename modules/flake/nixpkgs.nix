{ config, inputs, ... }:

let
  # The only place that knows how nixpkgs is instantiated for this lab. Exposed
  # as a module argument because colmena needs a package set for a system that
  # isn't in `systems` (see `meta.nixpkgs`).
  loadPkgs =
    system:
    import inputs.nixpkgs {
      inherit system;

      overlays = [
        config.flake.overlays.unstable-packages
      ];
    };
in

{
  systems = import inputs.systems;

  _module.args = { inherit loadPkgs; };

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = loadPkgs system;
    };
}
