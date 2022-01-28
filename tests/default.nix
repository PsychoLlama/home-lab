{ pkgs ? import ../machines/unstable-pkgs.nix { } }:

with pkgs.lib;

let
  loadTests = path:
    listToAttrs (attrValues (mapAttrs (_: test: nameValuePair test.name test)
      (import path { inherit pkgs; })));

in (loadTests ./router.nix) ++ loadTests (./vault-agent.nix)
