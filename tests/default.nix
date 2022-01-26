{ pkgs ? import ../machines/unstable-pkgs.nix { } }:

with pkgs.lib;

listToAttrs (attrValues (mapAttrs (_: test: nameValuePair test.name test)
  (import ./router.nix { inherit pkgs; })))
