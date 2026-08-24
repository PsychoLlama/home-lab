{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:

    let
      importTest = import ../../platforms/nixos/tests { inherit pkgs inputs; };
    in

    {
      checks = {
        dhcp = importTest ../../platforms/nixos/tests/dhcp.nix;
        dns = importTest ../../platforms/nixos/tests/dns.nix;
        gateway = importTest ../../platforms/nixos/tests/gateway.nix;
      };
    };
}
