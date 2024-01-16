{ callPackage }:

{
  dhcp = callPackage ./dhcp.nix { };
  # ...
}
