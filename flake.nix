{
  description = "Hobbyist home lab";
  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs }:
    let
      inherit (import ./machines/config.nix) domain;
      lib = import ./machines/lib.nix;

    in {
      nixopsConfigurations = {
        default = {
          inherit nixpkgs;

          network = {
            description = domain;
            enableRollback = true;
            storage.legacy = { databasefile = "~/.nixops/deployments.nixops"; };
          };

          multivac = lib.defineHost ./machines/hosts/multivac;
          hactar = lib.defineHost ./machines/hosts/hactar;
          corvus = lib.defineHost ./machines/hosts/corvus;
          viki = lib.defineHost ./machines/hosts/viki;
          hal = lib.defineHost ./machines/hosts/hal;
          clu = lib.defineHost ./machines/hosts/clu;
          tron = lib.defineHost ./machines/hosts/tron;
        };
      };

      checks = with nixpkgs.lib;
        listToAttrs (forEach [ "x86_64-linux" "aarch64-linux" ] (system:
          nameValuePair system (import ./machines/tests/router.nix {
            pkgs = import ./machines/unstable-pkgs.nix { inherit system; };
          })));
    };
}
