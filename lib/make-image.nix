{ nixosSystem, nixpkgs }:

# Infinite thanks to taylor1791 for source diving to figure this out.
# See: https://nixos.org/manual/nixpkgs/unstable/#sec-make-disk-image
import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
  inherit (nixosSystem) config pkgs;

  bootSize = "1G";
  format = "raw";
  lib = nixpkgs.lib;
  partitionTableType = "hybrid";
}
