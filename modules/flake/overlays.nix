{ inputs, ... }:

{
  # Add `pkgs.unstable` to the package set.
  flake.overlays.unstable-packages = final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (prev.stdenv.hostPlatform) system;
      inherit (prev) config;
    };
  };
}
