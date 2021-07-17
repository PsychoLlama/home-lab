{
  description = "Configuration for my home lab";

  outputs = inputs@{ self, nixpkgs }:

  let
    lib = import ./nixos/lib.nix inputs;

  in {
    nixosConfigurations = {
      corvus = lib.defineHost "x86_64-linux" ./nixos/hosts/corvus;
    };
  };
}
