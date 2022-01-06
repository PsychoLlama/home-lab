{
  description = "Hobbyist home lab";
  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs }:
    let defineHost = import ./machines/define-host.nix;

    in {
      nixopsConfigurations = {
        default = {
          inherit nixpkgs;

          network = let inherit (import ./machines/config.nix) domain;
          in {
            description = domain;
            enableRollback = true;
            storage.legacy.databasefile = "~/.nixops/deployments.nixops";
          };

          multivac = defineHost ./machines/hosts/multivac;
          hactar = defineHost ./machines/hosts/hactar;
          corvus = defineHost ./machines/hosts/corvus;
          viki = defineHost ./machines/hosts/viki;
          hal = defineHost ./machines/hosts/hal;
          clu = defineHost ./machines/hosts/clu;
          tron = defineHost ./machines/hosts/tron;
        };
      };

      checks = with nixpkgs.lib;
        listToAttrs (forEach [ "x86_64-linux" "aarch64-linux" ] (system:
          nameValuePair system (import ./machines/tests/router.nix {
            pkgs = import ./machines/unstable-pkgs.nix { inherit system; };
          })));
    };
}
